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

      def contents_with_default_scope(query = @contents)
        query = query.reorder(nil).reselect(content_select_sql).group('things.id')

        joins = include_config.pluck(:joins)
        joins.uniq!
        joins.compact!

        joins.each { |join| query = query.joins(join.squish) }

        query
      end

      def content_select_sql
        [
          'things.id AS id',
          'things.geom_simple AS geometry'
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
          joins: 'LEFT OUTER JOIN thing_templates ON thing_templates.template_name = things.template_name',
          select: 'array_to_json(MAX(thing_templates.computed_schema_types))'
        }

        if @fields_parameters.blank? || @fields_parameters&.any? { |p| p.first == 'name' }
          config << {
            identifier: 'name',
            select: "MAX(thing_translations.content ->> 'name') FILTER (
              WHERE thing_translations.content ->> 'name' IS NOT NULL
            )",
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
            select: 'json_agg(tmp1."dc:classification") FILTER (
              WHERE tmp1."dc:classification" IS NOT NULL
            )',
            joins: "LEFT OUTER JOIN LATERAL (
                  SELECT
                  collected_classification_contents.thing_id,
                  json_build_object(#{json_object.join(', ')}) AS \"dc:classification\"
                  FROM collected_classification_contents
                    INNER JOIN classification_aliases ON classification_aliases.id = collected_classification_contents.classification_alias_id
                    AND classification_aliases.deleted_at IS NULL
                    INNER JOIN classification_trees ON classification_trees.classification_alias_id = classification_aliases.id
                    AND classification_trees.deleted_at IS NULL
                    INNER JOIN classification_tree_labels ON classification_tree_labels.id = classification_trees.classification_tree_label_id
                    AND classification_tree_labels.deleted_at IS NULL
                    #{'INNER JOIN classification_alias_paths ON classification_alias_paths.id = classification_aliases.id' if fields_parameters.blank? || fields_parameters.include?('dc:path')}
                  WHERE 'api' = ANY(classification_tree_labels.visibility)
                    #{"AND classification_trees.classification_tree_label_id IN (\'#{@classification_trees_parameters.join('\',\'')}\')" if @classification_trees_parameters.present?}
                ) AS tmp1 ON tmp1.thing_id = things.id"
          }
        end

        config
      end
    end
  end
end
