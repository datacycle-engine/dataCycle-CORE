# frozen_string_literal: true

module DataCycleCore
  module Geo
    class MvtRenderer < ::DataCycleCore::Geo::BaseRenderer
      # SIMPLIFY_FACTOR = 0.00001

      def initialize(x, y, z, contents:, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false, **_options)
        # TODO: **options??
        super(contents: contents, simplify_factor: simplify_factor, include_parameters: include_parameters, fields_parameters: fields_parameters, classification_trees_parameters: classification_trees_parameters, single_item: single_item)

        @x = x
        @y = y
        @z = z
      end

      def render
        result(
          contents_with_default_scope(simplify_factor: 1 / (2**@z.to_f)),
          main_sql(mvt_sql(x, y, z))
        )
      end

      def result(things_query, geojson_query)
        ActiveRecord::Base.connection.unescape_bytea(
          super(things_query, geojson_query)
        )
      end

      def mvt_sql(x, y, z)
        # Resources:
        # https://github.com/CrunchyData/pg_tileserv
        # https://github.com/pramsey/minimal-mvt/
        # https://postgis.net/docs/ST_AsMVT.html
        # https://www.crunchydata.com/blog/crunchy-spatial-tile-serving-with-postgresql-functions
        # https://www.crunchydata.com/blog/waiting-for-postgis-3-st_tileenvelopezxy
        # def mvt_sql(select_sql)
        #   WITH
        #   bounds AS (
        #   SELECT ST_TileEnvelope(z, x, y) AS geom
        # ),
        #   -- Convert raw geometry into MVT geometry
        #   -- Pull just the name in addition to the geometry
        #   -- Apply the name_prefix parameter to the WHERE clause
        #   mvtgeom AS (
        #       SELECT ST_AsMVTGeom(ST_Transform(t.geom, 3857), bounds.geom) AS geom,
        #         t.name
        #       FROM ne_50m_admin_0_countries t, bounds
        #       WHERE ST_Intersects(t.geom, ST_Transform(bounds.geom, 4326))
        #       AND upper(t.name) LIKE (upper(name_prefix) || '%')
        #     )
        #     -- Serialize the result set into an MVT object
        #     SELECT ST_AsMVT(mvtgeom, 'public.countries_name') FROM mvtgeom;
        <<-SQL.squish
              WITH
              bounds AS (
                SELECT ST_TileEnvelope(#{z}, #{x}, #{y}) AS geom
              ),
              mvtgeom AS (
                SELECT ST_AsMVTGeom(ST_Transform(t.geometry, 3857), bounds.geom) AS geom,
                  t.id, t.name
                FROM (:from_query) as t, bounds
                WHERE ST_Intersects(t.geometry, ST_Transform(bounds.geom, 4326))
              )
              SELECT ST_AsMVT(mvtgeom, 'dataCycle') FROM mvtgeom;
        SQL
      end

      def include_config
        config = []

        config << {
          identifier: '"@type"',
          select: 'array_append(
                      CASE
                      WHEN things."schema"->\'api\'->\'type\' IS NOT NULL THEN
                      ARRAY(
                      SELECT
                        jsonb_array_elements_text(things."schema"->\'api\'->\'type\')
                      )
                      WHEN things."schema"->\'schema_type\' IS NOT NULL THEN
                      ARRAY(SELECT things."schema"->>\'schema_type\')
                      ELSE \'{"Thing"}\'
                      END,
                      \'dcls:\' || things.template_name)'
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
