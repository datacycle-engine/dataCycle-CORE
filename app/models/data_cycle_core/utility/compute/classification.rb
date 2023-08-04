# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Classification
        class << self
          def keywords(computed_parameters:, **_args)
            DataCycleCore::Classification.find(Array.wrap(computed_parameters.values).flatten.reject(&:blank?)).map(&:name).join(',').presence
          end

          def description(computed_parameters:, **_args)
            classification_ids = computed_parameters.values.flatten.reject(&:blank?)

            return if classification_ids.blank?

            DataCycleCore::Classification
              .where(id: classification_ids)
              .classification_aliases
              .map { |classification_alias| classification_alias.description || classification_alias.name || classification_alias.internal_name }
              &.join(',')
          end

          def value(computed_definition:, **_args)
            tree = computed_definition.dig('compute', 'tree')
            value = computed_definition.dig('compute', 'value')

            return if value.blank? || tree.blank?

            DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(tree, value)
          end

          def from_geo_shape(computed_parameters:, computed_definition:, **_args)
            values = []
            computed_definition.dig('compute', 'parameters')&.each do |parameter_key|
              location_value = Array.wrap(Common.get_values_from_hash(computed_parameters, parameter_key.split('.'))).first
              value = DataCycleCore::MasterData::DataConverter.string_to_geographic(location_value)

              next if value.blank?
              values << value
            end

            return if values.empty?

            values.map { |value|
              get_ids_from_geometry(tree_label: computed_definition.dig('tree_label'), geometry: value.to_s)
            }.flatten
            .compact
            .uniq
          end

          def from_embedded(computed_parameters:, computed_definition:, **_args)
            Array.wrap(computed_definition.dig('compute', 'parameters')&.map do |p|
              key_path = p.split('.')
              get_values_from_embedded(key_path.drop(1), computed_parameters.dig(key_path.first))
            end).flatten.compact.uniq
          end

          def get_ids_from_geometry(tree_label:, geometry:)
            query_sql = <<-SQL.squish
              WITH filtered_classifications AS (
                SELECT
                  classification_polygons.classification_alias_id
                FROM
                  classification_polygons
                  INNER JOIN classification_aliases ON classification_aliases.deleted_at IS NULL
                    AND classification_aliases.id = classification_polygons.classification_alias_id
                  INNER JOIN "classification_trees" ON "classification_trees"."deleted_at" IS NULL
                    AND "classification_trees"."classification_alias_id" = "classification_aliases"."id"
                  INNER JOIN "classification_tree_labels" ON "classification_tree_labels"."deleted_at" IS NULL
                    AND "classification_tree_labels"."id" = "classification_trees"."classification_tree_label_id"
                WHERE
                  "classification_tree_labels"."name" = :tree_label
                  AND ST_Intersects ("classification_polygons"."geom", ST_GeomFromText (:geo, 4326)))
              SELECT DISTINCT ON (classification_groups.classification_id)
                classification_groups.classification_id
              FROM
                classification_groups
              WHERE
                classification_groups.deleted_at IS NULL
                AND classification_groups.classification_alias_id IN (
                  SELECT
                    filtered_classifications.classification_alias_id
                  FROM
                    filtered_classifications
                  WHERE
                    NOT EXISTS (
                      SELECT
                      FROM
                        classification_alias_paths
                      WHERE
                        classification_alias_paths.ancestor_ids @> ARRAY[filtered_classifications.classification_alias_id]::uuid[]))
                ORDER BY
                  classification_groups.classification_id,
                  classification_groups.created_at
            SQL

            ActiveRecord::Base.connection.execute(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        query_sql,
                                        tree_label:,
                                        geo: geometry
                                      ])
            ).values.flatten
          end

          private

          def get_values_from_embedded(key_path, values)
            return values if key_path.blank?

            if values.is_a?(::Hash)
              key = key_path.first

              if values.key?(key) || values.dig('datahash')&.key?(key) || values.dig('translations', I18n.locale.to_s)&.key?(key)
                value = values.dig(key) || values.dig('datahash', key) || values.dig('translations', I18n.locale.to_s, key)
              else
                id = values.dig('id') || values.dig('datahash', 'id') || values.dig('translations', I18n.locale.to_s, 'id')
                item = DataCycleCore::Thing.find_by(id:)
                value = item.respond_to?(key) ? item.attribute_to_h(key) : nil
              end

              get_values_from_embedded(key_path.drop(1), value)
            elsif values.is_a?(::Array)
              values.map { |v| get_values_from_embedded(key_path, v) }
            else
              values
            end
          end
        end
      end
    end
  end
end
