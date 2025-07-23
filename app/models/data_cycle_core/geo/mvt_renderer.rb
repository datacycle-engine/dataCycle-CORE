# frozen_string_literal: true

module DataCycleCore
  module Geo
    class MvtRenderer < ::DataCycleCore::Geo::BaseRenderer
      # Resources:
      # https://github.com/CrunchyData/pg_tileserv
      # https://github.com/pramsey/minimal-mvt/
      # https://postgis.net/docs/ST_AsMVT.html
      # https://www.crunchydata.com/blog/crunchy-spatial-tile-serving-with-postgresql-functions
      # https://www.crunchydata.com/blog/waiting-for-postgis-3-st_tileenvelopezxy

      def initialize(x, y, z, **options)
        super(**options)

        @x = x
        @y = y
        @z = z
        @simplify_factor = 1 / (2**@z.to_f)
        @layer_name = options[:layer_name].presence || 'dataCycle'
        @cluster_layer_name = options[:cluster_layer_name].presence || 'dataCycleCluster'
        @cache = options[:cache] != false
        @cluster = options[:cluster] || false
        @cluster_lines = options[:cluster_lines] || false # cluster lines by start point
        @cluster_polygons = options[:cluster_polygons] || false # cluster polygons by start point
        @cluster_non_points = @cluster_lines || @cluster_polygons
        @cluster_items = options[:cluster_items] || false # render items inside cluster
        @cluster_max_zoom = options[:cluster_max_zoom]&.to_i
        @cluster_max_distance_dividend = options[:cluster_max_distance_dividend]&.to_f || 500_000
        @cluster_max_distance_divisor = options[:cluster_max_distance_divisor]&.to_f || 1.7
        @cluster_max_distance = (options[:cluster_max_distance]&.to_f || (@cluster_max_distance_dividend / (@cluster_max_distance_divisor**@z.to_f))).round(2)
        @cluster_min_points = options[:cluster_min_points]&.to_i || 2
        @include_linked = @include_parameters.any?(['linked'])
        @start_points_only = options[:start_points_only] || false
      end

      def render
        if @cache
          Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
            ActiveRecord::Base.connection.unescape_bytea(super)
          end
        else
          ActiveRecord::Base.connection.unescape_bytea(super)
        end
      end

      def main_sql
        @main_sql ||= cluster? ? mvt_clustered_sql : mvt_unclustered_sql
      end

      def contents_with_default_scope(query = @contents)
        query = query.except(:joins, :limit, :offset)
          .joins('INNER JOIN geometries ON geometries.thing_id = things.id AND geometries.is_primary = TRUE')
          .reorder(nil)
          .reselect(content_select_sql)
          .where(
            sanitize_sql(
              ["ST_Intersects(#{geometry_column}, ST_Transform(ST_TileEnvelope(#{@z}, #{@x}, #{@y}), 4326))"]
            )
          )

        query = query.select(sanitize_sql("ST_GeometryType(#{geometry_column}) AS geometry_type")).reorder(id: :desc) if cluster?

        query
      end

      def sanitize_sql(sql_array)
        ActiveRecord::Base.send(:sanitize_sql_array, sql_array)
      end

      def geometry_column
        @start_points_only ? 'ST_StartPoint(geometries.geom_simple)' : 'geometries.geom_simple'
      end

      def cluster?
        @cluster && (@cluster_max_zoom.blank? || @cluster_max_zoom >= @z.to_i)
      end

      def content_select_sql
        [
          'things.id AS id',
          'things.template_name AS template_name',
          "ST_Transform(ST_Simplify (#{geometry_column}, #{@simplify_factor}, TRUE), 3857) AS geometry"
        ]
      end

      def base_contents_subquery
        unless @include_linked
          return <<-SQL.squish
            WITH contents AS (
              #{contents_with_default_scope.to_sql}
            )
          SQL
        end

        base_things =
          DataCycleCore::Thing.default_scoped
            .where('EXISTS (SELECT 1 FROM base_things WHERE base_things.id = things.id)')
        base_things_query = contents_with_default_scope(base_things)

        additional_things = DataCycleCore::Thing.default_scoped
          .where.not(content_type: 'embedded')
          .where('EXISTS (SELECT 1 FROM base_things WHERE base_things.id = ccl.content_a_id)')
        additional_things_query = contents_with_default_scope(additional_things)
          .joins('INNER JOIN content_content_links ccl ON ccl.content_b_id = things.id')

        <<-SQL.squish
          WITH base_things AS (#{@contents.reorder(nil).reselect('things.*').to_sql}),
          selected_things AS (
            #{base_things_query.to_sql}
          ), additional_things AS (
            #{additional_things_query.to_sql}
          ), contents AS (
            SELECT * FROM selected_things
            UNION
            SELECT * FROM additional_things
          )
        SQL
      end

      def mvt_unclustered_sql
        as_mvt_select = sanitize_sql(
          [
            'SELECT ST_AsMVT(mvtgeom, :layer_name) FROM mvtgeom',
            {layer_name: @layer_name}
          ]
        )
        includes = include_config('t')

        <<-SQL.squish
          #{base_contents_subquery}, mvtgeom AS (
            SELECT ST_AsMVTGeom(MAX(t.geometry), ST_TileEnvelope(#{@z}, #{@x}, #{@y})) AS geom,
              t.id as "@id"
              #{includes.map { |c| "#{c[:select]} AS #{c[:identifier]}" }.join(', ').presence&.prepend(', ')}
            FROM contents as t
            #{includes.pluck(:joins).join(' ')}
            GROUP BY t.id
          )
          #{as_mvt_select};
        SQL
      end

      def mvt_clustered_select_sql
        layer_select_sql = <<-SQL.squish
          mvt_data AS (
            SELECT ST_AsMVT(items.*, :layer_name) AS mvtdata
            FROM items
            UNION ALL
            SELECT ST_AsMVT(clustered_items.*, :cluster_layer_name) AS mvtdata
            FROM clustered_items
          )
          SELECT string_agg(mvt_data.mvtdata, '')
          FROM mvt_data
        SQL

        sanitize_sql(
          [
            layer_select_sql,
            {layer_name: @layer_name,
             cluster_layer_name: @cluster_layer_name}
          ]
        )
      end

      def mvt_cluster_sql
        if @cluster_non_points
          "CASE WHEN ST_Intersects(ST_StartPoint(contents.geometry), ST_TileEnvelope(#{@z}, #{@x}, #{@y})) THEN ST_ClusterDBSCAN(ST_StartPoint(contents.geometry), #{@cluster_max_distance}, #{@cluster_min_points}) over (ORDER BY contents.id) ELSE NULL END"
        else
          "ST_ClusterDBSCAN(contents.geometry, #{@cluster_max_distance}, #{@cluster_min_points}) over (ORDER BY contents.id)"
        end
      end

      def mvt_cluster_unclustered_sql
        includes = include_config('contents')

        <<-SQL.squish
          UNION ALL
          SELECT ST_AsMVTGeom(MAX(contents.geometry), ST_TileEnvelope(#{@z}, #{@x}, #{@y})),
            contents.id AS "@id"
            #{includes.map { |c| "#{c[:select]} AS #{c[:identifier]}" }.join(', ').presence&.prepend(', ')}
          FROM contents
          #{includes.pluck(:joins).join(' ')}
          WHERE contents.geometry_type NOT IN (#{allowed_geometry_types})
          GROUP BY contents.id
        SQL
      end

      def mvt_cluster_items_select
        return unless @cluster_items

        <<-SQL.squish
          json_agg(clustered_contents.item) AS "items",
        SQL
      end

      def mvt_cluster_items_from
        return 'mvtgeom' unless @cluster_items

        includes = include_config('mvtgeom')

        <<-SQL.squish
          mvtgeom
          INNER JOIN (
            SELECT json_build_object(
                '@id',
                mvtgeom.id
                #{includes.map { |c| "'#{c[:identifier]}', #{c[:select]}" }.join(', ').presence&.prepend(', ')}
              ) AS "item",
            mvtgeom.id AS id
            FROM mvtgeom
            #{includes.pluck(:joins).join(' ')}
            WHERE mvtgeom.cluster_id IS NOT NULL
            GROUP BY mvtgeom.id
          ) clustered_contents ON clustered_contents.id = mvtgeom.id
        SQL
      end

      def allowed_geometry_types
        allowed_types = ['ST_Point']
        allowed_types.push('ST_LineString', 'ST_MultiLineString') if @cluster_lines
        allowed_types.push('ST_Polygon', 'ST_MultiPolygon') if @cluster_polygons
        allowed_types.map { |agt| "'#{agt}'" }.join(', ')
      end

      def mvt_clustered_sql
        includes = include_config('mvtgeom')

        <<-SQL.squish
          #{base_contents_subquery},
          mvtgeom AS (
            SELECT contents.geometry AS geom,
            contents.id AS id,
            contents.template_name AS template_name,
            #{mvt_cluster_sql} AS cluster_id
            FROM contents
            #{"WHERE contents.geometry_type IN (#{allowed_geometry_types})" unless @cluster_non_points}
          ),
          clustered_items AS (
            SELECT ST_AsMVTGeom(
                st_centroid(ST_Union(ST_StartPoint(mvtgeom.geom))),
                ST_TileEnvelope(#{@z}, #{@x}, #{@y})
              ),
              #{mvt_cluster_items_select}
              COUNT(mvtgeom.id) AS "count",
              concat('#{@z}-#{@x}-#{@y}-', mvtgeom.cluster_id) AS "@id",
              json_build_object(
                'xmin',
                st_xmin(ST_Extent(ST_Transform(ST_StartPoint(mvtgeom.geom), 4326))),
                'ymin',
                st_ymin(ST_Extent(ST_Transform(ST_StartPoint(mvtgeom.geom), 4326))),
                'xmax',
                st_xmax(ST_Extent(ST_Transform(ST_StartPoint(mvtgeom.geom), 4326))),
                'ymax',
                st_ymax(ST_Extent(ST_Transform(ST_StartPoint(mvtgeom.geom), 4326)))
              ) AS "bbox"
            FROM #{mvt_cluster_items_from}
            WHERE mvtgeom.cluster_id IS NOT NULL
            GROUP BY mvtgeom.cluster_id
          ),
          items AS (
            SELECT ST_AsMVTGeom(
                MAX(mvtgeom.geom),
                ST_TileEnvelope(#{@z}, #{@x}, #{@y})
              ),
              mvtgeom.id as "@id"
              #{includes.map { |c| "#{c[:select]} AS #{c[:identifier]}" }.join(', ').presence&.prepend(', ')}
            FROM mvtgeom
            #{includes.pluck(:joins).join(' ')}
            WHERE mvtgeom.cluster_id IS NULL
            GROUP BY mvtgeom.id
            #{mvt_cluster_unclustered_sql unless @cluster_lines && @cluster_polygons}
          ),
          #{mvt_clustered_select_sql};
        SQL
      end
    end
  end
end
