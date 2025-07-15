# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    class ElevationProfileRenderer
      attr_reader :query

      def initialize(content:, locale: I18n.default_locale, data_format: nil)
        @data_format = data_format || 'object'
        @content = content
        @locale = locale

        raise ActiveRecord::RecordNotFound if content.nil?

        unless content&.geo_properties&.key?('line') && content.line.present?
          @status_code = :not_found
          @error = I18n.t('api_renderer.elevation_profile_renderer.errors.no_geodata', locale: @locale)
          return
        end

        return if content.elevation_data?('line')

        @status_code = :not_found
        @error = I18n.t('api_renderer.elevation_profile_renderer.errors.no_elevation_data', locale: @locale)
      end

      def render
        raise Error::RendererError.new(@error, @status_code) if @error.present?

        transform_data
      end

      def sql_for_data_format(combined_format)
        return send(combined_format) if respond_to?(combined_format)

        raise Error::RendererError, I18n.t('api_renderer.elevation_profile_renderer.errors.illegal_combination', locale: @locale)
      end

      def transform_data
        ActiveRecord::Base.connection.select_all(
          Arel.sql(
            sql_for_data_format("json_#{@data_format}")
          )
        ).first&.values&.first
      end

      def base_query
        <<-SQL.squish
          WITH points AS (
            SELECT (ST_DumpPoints(geometries.geom)).geom AS geom
            FROM geometries
            WHERE geometries.thing_id = '#{@content.id}'
              AND geometries.is_primary = true
              AND GeometryType(geometries.geom) IN ('LINESTRING', 'MULTILINESTRING')
            ORDER BY (ST_DumpPoints(geometries.geom)).path
          ),
          distances_points AS (
            SELECT points.geom,
              ST_Z(points.geom) AS elevation,
              ST_Distance(
                (lag(points.geom, 1) over w)::geography,
                points.geom::geography
              ) AS distance,
              row_number() over w AS "index"
            FROM points window w AS ()
          ),
          distances_start AS (
            SELECT round(
                coalesce(
                  sum(distances_points.distance) over (
                    ORDER BY INDEX
                  ),
                  0
                )::numeric,
                2
              ) AS distance,
              distances_points.elevation,
              distances_points.geom
            FROM distances_points
          )
        SQL
      end

      def json_array
        <<-SQL.squish
          #{base_query}
          SELECT json_build_object(
            'data',
            json_agg(
              json_build_array(
                distances_start.distance,
                distances_start.elevation,
                json_build_array(
                  ST_X(distances_start.geom),
                  ST_Y(distances_start.geom)
                )
              )
            ),
            'meta',
            json_build_object('scaleX', 'm', 'scaleY', 'm')
          )
          FROM distances_start;
        SQL
      end

      def json_object
        <<-SQL.squish
          #{base_query}
          SELECT json_build_object(
            'data',
            json_agg(
              json_build_object(
                'x',
                distances_start.distance,
                'y',
                distances_start.elevation,
                'coordinates',
                json_build_array(
                  ST_X(distances_start.geom),
                  ST_Y(distances_start.geom)
                )
              )
            ),
            'meta',
            json_build_object('scaleX', 'm', 'scaleY', 'm')
          )
          FROM distances_start;
        SQL
      end
    end
  end
end

ActiveSupport.run_load_hooks :data_cycle_api_renderer_elevation_profile_renderer, DataCycleCore::ApiRenderer::ElevationProfileRenderer
