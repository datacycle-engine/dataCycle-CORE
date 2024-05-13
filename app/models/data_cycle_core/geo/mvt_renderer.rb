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

      def initialize(x, y, z, contents:, layer_name: nil, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false, cache: true, cluster: false, cluster_lines: false, cluster_items: false, cluster_layer_name: nil, **_options)
        super(contents:, simplify_factor:, include_parameters:, fields_parameters:, classification_trees_parameters:, single_item:, cache:)

        @x = x
        @y = y
        @z = z
        @simplify_factor = 1 / (2**@z.to_f)
        @layer_name = layer_name.presence || 'dataCycle'
        @cluster_layer_name = cluster_layer_name.presence || 'dataCycleCluster'
        @cache = cache
        @cluster = cluster
        @cluster_lines = cluster_lines
        @cluster_items = cluster_items
        @cluster_radius = 500_000 / (1.7**@z.to_f)
        @include_linked = @include_parameters.any?(['linked'])
      end

      def render
        if @cache
          Rails.cache.fetch(Digest::SHA1.hexdigest(main_sql), expires_in: 5.minutes) do
            ActiveRecord::Base.connection.unescape_bytea(super)
          end
        else
          ActiveRecord::Base.connection.unescape_bytea(super)
        end
      end

      def contents_with_default_scope(query = @contents)
        query = super(query)

        query = query.where(
          ActiveRecord::Base.send(:sanitize_sql_array, ["ST_Intersects(things.geom_simple, ST_Transform(ST_TileEnvelope(#{@z}, #{@x}, #{@y}), 4326))"])
        )

        query = query.select('ST_GeometryType(MAX(things.geom_simple)) AS geometry_type').reorder(id: :desc) if @cluster

        query
      end

      def content_select_sql
        [
          'things.id AS id',
          "ST_Transform(ST_Simplify (MAX(things.geom_simple), #{@simplify_factor}, TRUE), 3857) AS geometry"
        ]
          .concat(include_config.map { |c| "#{c[:select]} AS #{c[:identifier]}" })
          .join(', ').squish
      end

      def main_sql
        @cluster ? mvt_clustered_sql : mvt_unclustered_sql
      end

      def base_contents_subquery
        unless @include_linked
          return <<-SQL.squish
            WITH contents AS (
              #{contents_with_default_scope.to_sql}
            )
          SQL
        end

        additional_things_query = DataCycleCore::Thing.default_scoped.from('base_things')
          .joins('INNER JOIN content_contents cc ON cc.content_a_id = base_things.id INNER JOIN things ON things.id = cc.content_b_id')
          .where.not(content_type: 'embedded')

        <<-SQL.squish
          WITH base_things AS (#{@contents.reorder(nil).reselect('things.*').to_sql}),
          selected_things AS (
            #{contents_with_default_scope(DataCycleCore::Thing.default_scoped.from('base_things things')).to_sql}
          ), additional_things AS (
            #{contents_with_default_scope(additional_things_query).to_sql}
          ), contents AS (
            SELECT * FROM selected_things
            UNION ALL
            SELECT * FROM additional_things
          )
        SQL
      end

      def mvt_unclustered_sql
        as_mvt_select = ActiveRecord::Base.send(:sanitize_sql_array, ['SELECT ST_AsMVT(mvtgeom, :layer_name) FROM mvtgeom', layer_name: @layer_name])

        <<-SQL.squish
          #{base_contents_subquery}, mvtgeom AS (
            SELECT ST_AsMVTGeom(t.geometry, ST_TileEnvelope(#{@z}, #{@x}, #{@y})) AS geom,
              t.id as "@id",
              #{include_config.pluck(:identifier).map { |p| "t.#{p} as #{p}" }.join(', ')}
            FROM contents as t
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

        ActiveRecord::Base.send(:sanitize_sql_array, [
                                  layer_select_sql,
                                  layer_name: @layer_name,
                                  cluster_layer_name: @cluster_layer_name
                                ])
      end

      def mvt_cluster_sql
        if @cluster_lines
          "CASE WHEN ST_Intersects(ST_StartPoint(contents.geometry), ST_TileEnvelope(#{@z}, #{@x}, #{@y})) THEN ST_ClusterDBSCAN(ST_StartPoint(contents.geometry), #{@cluster_radius}, 2) over () ELSE NULL END"
        else
          "ST_ClusterDBSCAN(contents.geometry, #{@cluster_radius}, 2) over ()"
        end
      end

      def mvt_cluster_unclustered_sql
        <<-SQL.squish
          UNION ALL
          SELECT ST_AsMVTGeom(contents.geometry, ST_TileEnvelope(#{@z}, #{@x}, #{@y})),
            contents.id AS "@id",
            #{include_config.pluck(:identifier).map { |p| "contents.#{p} as #{p}" }.join(', ')}
          FROM contents
          WHERE contents.geometry_type != 'ST_Point'
        SQL
      end

      def mvt_cluster_items
        return unless @cluster_items

        <<-SQL.squish
          json_agg(json_build_object('@id', mvtgeom."@id", #{include_config.pluck(:identifier).map { |p| "'#{p}', mvtgeom.#{p}" }.join(', ')})) AS "items",
        SQL
      end

      def mvt_clustered_sql
        <<-SQL.squish
          #{base_contents_subquery},
          mvtgeom AS (
            SELECT contents.geometry AS geom,
            contents.id AS "@id",
            #{mvt_cluster_sql} AS cluster_id,
            #{include_config.pluck(:identifier).map { |p| "contents.#{p} as #{p}" }.join(', ')}
            FROM contents
            #{"WHERE contents.geometry_type = 'ST_Point'" unless @cluster_lines}
          ),
          clustered_items AS (
            SELECT ST_AsMVTGeom(
                st_centroid(ST_Union(ST_StartPoint(mvtgeom.geom))),
                ST_TileEnvelope(#{@z}, #{@x}, #{@y})
              ),
              #{mvt_cluster_items}
              COUNT(mvtgeom."@id") AS "count",
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
            FROM mvtgeom
            WHERE mvtgeom.cluster_id IS NOT NULL
            GROUP BY mvtgeom.cluster_id
          ),
          items AS (
            SELECT ST_AsMVTGeom(
                mvtgeom.geom,
                ST_TileEnvelope(#{@z}, #{@x}, #{@y})
              ),
              mvtgeom."@id" as "@id",
              #{include_config.pluck(:identifier).map { |p| "mvtgeom.#{p} as #{p}" }.join(', ')}
            FROM mvtgeom
            WHERE mvtgeom.cluster_id IS NULL
            #{mvt_cluster_unclustered_sql unless @cluster_lines}
          ),
          #{mvt_clustered_select_sql};
        SQL
      end
    end
  end
end
