# frozen_string_literal: true

module DataCycleCore
  module Geo
    class GeojsonRenderer < ::DataCycleCore::Geo::BaseRenderer
      SIMPLIFY_FACTOR = 0.00001
      GEOMETRY_PRECISION = 5
      CRS_SQL = ", 'crs', json_build_object('type', 'name', 'properties', json_build_object('name', 'urn:ogc:def:crs:EPSG::4326'))"

      def render
        result(
          contents_with_default_scope(simplify_factor: @simplify_factor.presence || SIMPLIFY_FACTOR),
          main_sql(@single_item ? geojson_detail_select_sql : geojson_select_sql)
        )
      end

      def geojson_detail_select_sql
        <<-SQL.squish
              json_build_object('type', 'Feature', 'id', t.id, 'geometry', ST_AsGeoJSON (t.geometry, #{GEOMETRY_PRECISION})::json, 'properties',
                json_build_object('@id', t.id, #{include_config.pluck(:identifier).map { |p| "'#{p.delete('"')}', t.#{p}" }.join(', ')}))
        SQL
      end

      def geojson_select_sql
        <<-SQL.squish
              json_build_object('type', 'FeatureCollection'#{CRS_SQL}, 'features', json_agg(#{geojson_detail_select_sql}))
        SQL
      end
    end
  end
end
