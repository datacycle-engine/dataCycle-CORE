# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Classification
        extend Extensions::ValueByPathExtension

        class << self
          def keywords(computed_parameters:, **_args)
            DataCycleCore::Classification
              .by_ordered_values(Array.wrap(computed_parameters.values).flatten.compact_blank)
              .map(&:name)
              .join(',')
              .presence
          end

          def description(computed_parameters:, **_args)
            classification_ids = computed_parameters.values.flatten.compact_blank

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
              location_value = Array.wrap(get_values_from_hash(data: computed_parameters, key_path: parameter_key.split('.'))).first

              next if location_value.blank?

              if (location_value.is_a?(::String) && location_value.uuid?) || (location_value.is_a?(::Array) && location_value.first.to_s.uuid?)
                polygons = DataCycleCore::Concept
                  .where(classification_id: Array.wrap(location_value).compact_blank)
                  .classification_polygons

                polygons.each do |polygon|
                  value = DataCycleCore::MasterData::DataConverter.string_to_geographic(polygon.geom)
                  next if value.blank?
                  values << value
                end
              elsif location_value.is_a?(::String)
                values << location_value
              else
                value = DataCycleCore::MasterData::DataConverter.geographic_to_string(location_value)
                next if value.blank?
                values << value
              end
            end

            return if values.empty?

            values.map { |value|
              get_ids_from_geometry(tree_label: computed_definition['tree_label'], geometry: value.to_s)
            }.flatten
              .compact_blank
              .uniq
          end

          def copy_from_path(computed_parameters:, computed_definition:, **_args)
            Array.wrap(computed_definition.dig('compute', 'parameters')&.map do |path|
              Array.wrap(get_values_from_hash(data: computed_parameters, key_path: path.split('.')))
            end).flatten.compact_blank.uniq
          end

          def from_embedded(computed_parameters:, computed_definition:, **_args)
            Array.wrap(computed_definition.dig('compute', 'parameters')&.map do |path|
              key_path = path.split('.')
              get_values_from_embedded(key_path.drop(1), computed_parameters[key_path.first])
            end).flatten.compact_blank.uniq
          end

          def get_ids_from_geometry(tree_label:, geometry:)
            query_sql = <<-SQL.squish
              WITH filtered_classifications AS (
                SELECT
                  classification_polygons.classification_alias_id,
                    concepts.classification_id
                FROM
                  classification_polygons
                  INNER JOIN concepts ON concepts.id = classification_polygons.classification_alias_id
                  INNER JOIN concept_schemes ON concept_schemes.id = concepts.concept_scheme_id
                WHERE
                  concept_schemes.name = :tree_label
                  AND ST_Intersects (classification_polygons.geom_simple, ST_GeomFromText (:geo, 4326)))
              SELECT DISTINCT filtered_classifications.classification_id
              FROM filtered_classifications
              WHERE NOT EXISTS (
                  SELECT 1
                  FROM classification_alias_paths
                  WHERE classification_alias_paths.ancestor_ids @> ARRAY [filtered_classifications.classification_alias_id]::uuid []
                )
              ORDER BY filtered_classifications.classification_id
            SQL

            ActiveRecord::Base.connection.select_all(
              ActiveRecord::Base.send(:sanitize_sql_array, [
                                        query_sql,
                                        {tree_label:,
                                         geo: geometry}
                                      ])
            ).rows.flatten
          end

          # example config:
          # :compute:
          # :module: Classification
          # :method: by_concept_scheme_and_mapping
          # :key: external_key
          # :concept_scheme: Öffnungsstatus
          # :source_concept_scheme: ODTA - Tourenstatus
          # :mapping:
          #   open: Open
          #   closed: Closed
          #   temporarily closed: Closed
          #   closed off: Closed
          # :parameters:
          #   - odta_trail_status
          def by_concept_scheme_and_mapping(computed_parameters:, computed_definition:, **_args)
            ids = computed_parameters.values.flatten.compact_blank

            return if ids.blank?

            source_concepts = DataCycleCore::Concept.where(classification_id: ids)
            source_concepts = source_concepts.for_tree(computed_definition.dig('compute', 'source_concept_scheme')) if computed_definition.dig('compute', 'source_concept_scheme').present?
            mapping = computed_definition.dig('compute', 'mapping').to_h
            key = computed_definition.dig('compute', 'key').presence || 'internal_name'
            source_concepts = source_concepts.pluck(key.to_sym)
            concepts = DataCycleCore::Concept.for_tree(computed_definition.dig('compute', 'concept_scheme')).to_h { |c| [c.send(key), c.classification_id] }

            source_concepts.filter_map do |source_concept|
              concepts[mapping[source_concept] || source_concept]
            end
          end

          private

          def get_values_from_embedded(key_path, values)
            return values if key_path.blank?

            if values.is_a?(::Hash)
              key = key_path.first

              if values.key?(key) || values['datahash']&.key?(key) || values.dig('translations', I18n.locale.to_s)&.key?(key)
                value = values[key] || values.dig('datahash', key) || values.dig('translations', I18n.locale.to_s, key)
              else
                id = values['id'] || values.dig('datahash', 'id') || values.dig('translations', I18n.locale.to_s, 'id')
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
