# frozen_string_literal: true

module DataCycleCore
  module Geo
    class BaseRenderer
      def initialize(contents:, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false, **_options)
        @contents = contents
        @simplify_factor = simplify_factor
        @include_parameters = include_parameters
        @fields_parameters = fields_parameters
        @classification_trees_parameters = classification_trees_parameters
        @single_item = single_item
      end

      def render
        ActiveRecord::Base.connection.execute(
          Arel.sql(main_sql)
        ).first&.values&.first
      end

      def contents_with_default_scope
        query = @contents.except(:order).select(content_select_sql)

        joins = include_config.pluck(:joins)
        joins.uniq!
        joins.compact!

        joins.each { |join| query = query.joins(join.squish) }

        query
      end

      def content_select_sql
        [
          'things.id AS id',
          'geom_simple AS geometry'
        ]
          .concat(include_config.map { |c| "#{c[:select]} AS #{c[:identifier]}" })
          .join(', ').squish
      end

      def main_sql
        raise NotImplementedError
      end

      def include_config
        config = []

        config << {
          identifier: '"@type"',
          select: 'array_to_json(array_append(
                      CASE
                      WHEN things."schema"->\'api\'->\'type\' IS NOT NULL THEN
                      ARRAY(
                      SELECT
                        jsonb_array_elements_text(\'[]\'::jsonb || (things."schema" -> \'api\' -> \'type\'))
                      )
                      WHEN things."schema"->\'schema_type\' IS NOT NULL THEN
                      ARRAY(SELECT things."schema"->>\'schema_type\')
                      ELSE \'{"Thing"}\'
                      END,
                      \'dcls:\' || things.template_name))'
        }

        if @fields_parameters.blank? || @fields_parameters&.any? { |p| p.first == 'name' }
          config << {
            identifier: 'name',
            select: 'thing_translations.name',
            joins: "LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = things.id
                        AND thing_translations.locale = '#{I18n.locale}'"
          }
        end

        if @include_parameters&.any? { |p| p.first == 'dc:classification' } || @fields_parameters&.any? { |p| p.first == 'dc:classification' }
          fields_parameters = @fields_parameters.select { |p| p.first == 'dc:classification' }.map { |p| p.except('dc:classification') }.compact_blank.flatten
          json_object = []
          json_object.push("'@id', classification_aliases.id") if fields_parameters.blank? || fields_parameters.include?('@id')
          json_object.push("'dc:path', classification_alias_paths.full_path_names") if fields_parameters.blank? || fields_parameters.include?('dc:path')

          config << {
            identifier: '"dc:classification"',
            select: 'tmp1."dc:classification"',
            joins: "LEFT OUTER JOIN (
                  SELECT
                    classification_contents.content_data_id,
                    json_agg(
                      json_build_object(#{json_object.join(', ')})
                    ) AS \"dc:classification\"
                  FROM
                    classification_aliases
                    INNER JOIN classification_groups ON classification_groups.deleted_at IS NULL
                    AND classification_groups.classification_alias_id = classification_aliases.id
                    INNER JOIN classifications ON classifications.deleted_at IS NULL
                    AND classifications.id = classification_groups.classification_id
                    INNER JOIN classification_trees ON classification_trees.deleted_at IS NULL
                    AND classification_trees.classification_alias_id = classification_aliases.id
                    INNER JOIN classification_tree_labels ON classification_tree_labels.deleted_at IS NULL
                    AND classification_tree_labels.id = classification_trees.classification_tree_label_id
                    INNER JOIN classification_contents ON classification_contents.classification_id = classifications.id
                    #{'INNER JOIN classification_alias_paths ON classification_alias_paths.id = classification_aliases.id' if fields_parameters.blank? || fields_parameters.include?('dc:path')}
                  WHERE
                    classification_aliases.deleted_at IS NULL
                    AND 'api' = ANY(classification_tree_labels.visibility)
                    #{"AND classification_trees.classification_tree_label_id IN (\'#{@classification_trees_parameters.join('\',\'')}\')" if @classification_trees_parameters.present?}
                  GROUP BY
                    classification_contents.content_data_id
                ) AS tmp1 ON tmp1.content_data_id = things.id"
          }
        end

        config
      end
    end
  end
end
