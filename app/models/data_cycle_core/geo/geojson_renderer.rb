# frozen_string_literal: true

module DataCycleCore
  module Geo
    class GeojsonRenderer < ::DataCycleCore::Geo::BaseRenderer
      GEOMETRY_PRECISION = 5
      CRS_SQL = ", 'crs', json_build_object('type', 'name', 'properties', json_build_object('name', 'urn:ogc:def:crs:EPSG::4326'))"

      def render
        super || empty_geojson
      end

      def contents_with_default_scope(query = @contents)
        query = super(query)

        query = query.where.not(geom_simple: nil)

        query
      end

      def main_sql
        <<-SQL.squish
              SELECT #{@single_item ? geojson_detail_select_sql : geojson_select_sql}
              FROM (#{contents_with_default_scope.to_sql}) AS t
        SQL
      end

      def geojson_detail_select_sql
        <<-SQL.squish
              json_build_object(
                'type',
                'Feature',
                'id',
                t.id,
                'geometry',
                CASE WHEN ST_GeometryType(t.geometry) != 'ST_Point' THEN ST_AsGeoJSON (t.geometry, #{GEOMETRY_PRECISION}, 1)::json ELSE ST_AsGeoJSON (t.geometry, #{GEOMETRY_PRECISION})::json END,
                'properties',
                json_build_object('@id', t.id, #{include_config.pluck(:identifier).map { |p| "'#{p.delete('"')}', t.#{p}" }.join(', ')})
              )
        SQL
      end

      def geojson_select_sql
        <<-SQL.squish
              json_build_object(
                'type',
                'FeatureCollection'#{CRS_SQL},
                'features',
                json_agg(#{geojson_detail_select_sql}),
                'bbox',
                json_build_array(
                    st_xmin(ST_Extent(t.geometry)),
                    st_ymin(ST_Extent(t.geometry)),
                    st_xmax(ST_Extent(t.geometry)),
                    st_ymax(ST_Extent(t.geometry))
                  )
              )
        SQL
      end

      def empty_geojson
        {
          'type': 'Feature',
          'geometry': nil,
          'properties': nil
        }.to_json
      end
    end
  end
end
