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
        ActiveRecord::Base.connection.select_all(
          Arel.sql(main_sql)
        ).first&.values&.first
      end

      def contents_with_default_scope(query = @contents)
        query = query.reorder(nil).joins(:primary_geometry).reselect(content_select_sql).group('things.id, geometries.id')

        joins = include_config.pluck(:joins)
        joins.uniq!
        joins.compact!

        joins.each { |join| query = query.joins(join.squish) }

        query
      end

      def content_select_sql
        [
          'things.id AS id',
          'geometries.geom_simple AS geometry'
        ]
          .concat(include_config.map { |c| "#{c[:select]} AS #{c[:identifier]}" })
          .join(', ').squish
      end

      def main_sql
        raise NotImplementedError
      end

      def include_config
        config = []

        config << include_type
        config << include_name if @fields_parameters.blank? || @fields_parameters&.any? { |p| p.first == 'name' }
        config << include_dc_classification if field_required?('dc:classification')
        config << include_image if field_required?('image')
        config << include_internal_content_score if field_required?('dc:contentScore')

        config
      end

      private

      def field_required?(key)
        @include_parameters&.any? { |p| p.first.underscore == key.underscore } ||
          @fields_parameters&.any? { |p| p.first.underscore == key.underscore }
      end

      def include_type
        {
          identifier: '"@type"',
          joins: 'LEFT OUTER JOIN thing_templates ON thing_templates.template_name = things.template_name',
          select: 'array_to_json(MAX(thing_templates.api_schema_types))'
        }
      end

      def include_name
        {
          identifier: 'name',
          select: "MAX(thing_translations.content ->> 'name') FILTER (
            WHERE thing_translations.content ->> 'name' IS NOT NULL
          )",
          joins: "LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = things.id
                      AND thing_translations.locale = '#{I18n.locale}'"
        }
      end

      def include_dc_classification
        fields_parameters = @fields_parameters.select { |p| p.first == 'dc:classification' }.map { |p| p.except('dc:classification') }.compact_blank.flatten
        json_object = []
        json_object.push("'@id', concepts.id") if fields_parameters.blank? || fields_parameters.include?('@id')
        json_object.push("'dc:path', classification_alias_paths.full_path_names") if fields_parameters.blank? || fields_parameters.include?('dc:path')

        # collected_classification_contents can't be filtered by link_type yet, wait for https://ticket.pixelpoint.at/issues/39929

        {
          identifier: '"dc:classification"',
          select: 'json_agg(tmp1."dc:classification") FILTER (
            WHERE tmp1."dc:classification" IS NOT NULL
          )',
          joins: "LEFT OUTER JOIN LATERAL (
                SELECT collected_classification_contents.thing_id,
                json_build_object(#{json_object.join(', ')}) AS \"dc:classification\"
                FROM collected_classification_contents
                  INNER JOIN concepts ON concepts.id = collected_classification_contents.classification_alias_id
                  INNER JOIN concept_schemes ON concept_schemes.id = concepts.concept_scheme_id
                  #{'INNER JOIN classification_alias_paths ON classification_alias_paths.id = concepts.id' if fields_parameters.blank? || fields_parameters.include?('dc:path')}
                WHERE 'api' = ANY(concept_schemes.visibility)
                  #{"AND concepts.concept_scheme_id IN (\'#{@classification_trees_parameters.join('\',\'')}\')" if @classification_trees_parameters.present?}
              ) AS tmp1 ON tmp1.thing_id = things.id"
        }
      end

      def include_image
        fields_parameters = @fields_parameters.select { |p| p.first == 'image' }.map { |p| p.except('image') }.compact_blank.flatten
        include_parameters = @include_parameters.select { |p| p.first == 'image' }.map { |p| p.except('image') }.compact_blank.flatten
        json_object = []
        json_object.push("'@id', things.id") if fields_parameters.blank? || fields_parameters.include?('@id')
        json_object.push("'thumbnailUrl', COALESCE(things.metadata->>'virtual_thumbnail_url', things.metadata->>'thumbnail_url')") if fields_parameters.include?('thumbnailUrl') || include_parameters.include?('thumbnailUrl')

        {
          identifier: '"image"',
          select: 'json_agg(tmp2."image") FILTER (
            WHERE tmp2."image" IS NOT NULL
          )',
          joins: "LEFT OUTER JOIN LATERAL (
                SELECT content_content_links.content_a_id AS thing_id,
                json_build_object(#{json_object.join(', ')}) AS \"image\"
                FROM content_content_links
                  INNER JOIN things ON things.id = content_content_links.content_b_id
                WHERE content_content_links.relation = 'image'
              ) AS tmp2 ON tmp2.thing_id = things.id"
        }
      end

      def include_internal_content_score
        {
          identifier: '"dc:contentScore"',
          select: "MAX((thing_translations.content ->> 'internal_content_score')::integer) FILTER (
            WHERE thing_translations.content ->> 'internal_content_score' IS NOT NULL
          )",
          joins: "LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = things.id
                      AND thing_translations.locale = '#{I18n.locale}'"
        }
      end

      def cache_key
        @cache_key ||= Digest::SHA1.hexdigest(main_sql)
      end
    end
  end
end
