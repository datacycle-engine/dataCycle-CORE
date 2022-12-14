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

      def initialize(x, y, z, contents:, layer_name: nil, simplify_factor: nil, include_parameters: [], fields_parameters: [], classification_trees_parameters: [], single_item: false, **_options)
        super(contents: contents, simplify_factor: simplify_factor, include_parameters: include_parameters, fields_parameters: fields_parameters, classification_trees_parameters: classification_trees_parameters, single_item: single_item)

        @x = x
        @y = y
        @z = z
        @layer_name = layer_name.presence || 'dataCycle'
      end

      def render
        ActiveRecord::Base.connection.unescape_bytea(
          super
        )
      end

      def contents_with_default_scope(simplify_factor:)
        query = super(simplify_factor: simplify_factor)

        query = query.from('bounds, things')
        query = query.where('ST_Intersects(line, ST_Transform(bounds.geom, 4326)) OR ST_Intersects(location, ST_Transform(bounds.geom, 4326))')

        query
      end

      def main_sql
        as_mvt_select = ActiveRecord::Base.send(:sanitize_sql_array, ['SELECT ST_AsMVT(mvtgeom, :layer_name) FROM mvtgeom', layer_name: @layer_name])

        <<-SQL.squish
              WITH
              bounds AS (
                SELECT ST_TileEnvelope(#{@z}, #{@x}, #{@y}) AS geom
              ),
              mvtgeom AS (
                SELECT #{mvt_select_sql}
                FROM (#{contents_with_default_scope(simplify_factor: 1 / (2**@z.to_f)).to_sql}) as t, bounds
              )
              #{as_mvt_select};
        SQL
      end

      def mvt_select_sql
        <<-SQL.squish
              ST_AsMVTGeom(ST_Transform(t.geometry, 3857), bounds.geom) AS geom,
                  t.id as "@id", #{include_config.pluck(:identifier).map { |p| "t.#{p} as #{p}" }.join(', ')}
        SQL
      end
    end
  end
end
