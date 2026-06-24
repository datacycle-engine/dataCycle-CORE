# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Geo
        POINT_TYPES = ['POINT', 'MULTIPOINT'].freeze
        LINE_TYPES = ['LINESTRING', 'MULTILINESTRING'].freeze
        POLYGON_TYPES = ['POLYGON', 'MULTIPOLYGON'].freeze
        WKT_POINT_REGEX = Regexp.new("^(#{POINT_TYPES.join('|')}).*")
        WKT_LINE_REGEX = Regexp.new("^(#{LINE_TYPES.join('|')}).*")
        WKT_POLYGON_REGEX = Regexp.new("^(#{POLYGON_TYPES.join('|')}).*")
        TYPE_VALIDATIONS = {
          point: Regexp.new(POINT_TYPES.join('|'), Regexp::IGNORECASE),
          line: Regexp.new(LINE_TYPES.join('|'), Regexp::IGNORECASE),
          polygon: Regexp.new(POLYGON_TYPES.join('|'), Regexp::IGNORECASE)
        }.freeze

        def geo_filter(value = nil, type = nil)
          filter_type = type.to_sym
          raise 'Unknown geo filter' unless respond_to?(filter_type)

          send(filter_type, value)
        end

        def not_geo_filter(value = nil, type = nil)
          filter_type = :"not_#{type}"
          raise 'Unknown geo filter' unless respond_to?(filter_type)

          send(filter_type, value)
        end

        def within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(intersects(geometries_table[:geom_simple], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326)))
              ).exists
            )
          )
        end

        def not_within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(intersects(geometries_table[:geom_simple], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326)).not)
              ).exists
            )
          )
        end

        def geo_radius(values)
          subquery = geo_radius_subquery(values)
          return self if subquery.nil?

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(subquery)
              ).exists
            )
          )
        end

        def not_geo_radius(values)
          subquery = geo_radius_subquery(values)
          return self if subquery.nil?

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(subquery.not)
              ).exists
            )
          )
        end

        def geo_within_classification(ids)
          return self if ids.blank?

          # The approach of chaining ORs is still the most efficient though not the prettiest
          # Following variants where considered:
          # * ST_Union of all classification-geometries -> does not use an index on the resulting multi-geometry
          # * ST_Intersect on all classification-geometries whith pre-filter on classification_alias_id and a BBOX-filter on geometries (&&) -> inides not optimally used
          contains_queries = []
          ids.each do |id|
            sub_query = DataCycleCore::ClassificationPolygon
              .select(:geom)
              .limit(1)
              .where(classification_alias_id: id)
              .arel

            contains_queries << st_intersects(sub_query, geometries_table[:geom_simple])
          end

          reflect(
            @query
              .where(
                DataCycleCore::Geometry.select(1).arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                  .and(contains_queries.reduce(:or))
                ).exists
              )
          )
        end

        def not_geo_within_classification(ids)
          return self if ids.blank?

          contains_queries = []
          ids.each do |id|
            sub_query = DataCycleCore::ClassificationPolygon
              .select(:geom)
              .limit(1)
              .where(classification_alias_id: id)
              .arel

            contains_queries << st_intersects(sub_query, geometries_table[:geom_simple]).not
          end

          reflect(
            @query
              .where(
                DataCycleCore::Geometry.select(1).arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                  .and(contains_queries.reduce(:or))
                ).exists
              )
          )
        end

        def with_geometry
          reflect(
            @query
              .where(
                DataCycleCore::Geometry.select(1).arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                ).exists
              )
          )
        end

        def not_with_geometry
          reflect(
            @query
              .where.not(
                DataCycleCore::Geometry.select(1).arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                ).exists
              )
          )
        end

        def geo_type(value)
          return self if value.blank?

          return with_geometry if value.include? 'any'

          geom_type = geom_type_filter_builder(value)

          reflect(
            @query
              .where(
                DataCycleCore::Geometry.select(1).arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                  .and(geometry_type(geometries_table[:geom_simple]).in(geom_type))
                ).exists
              )
          )
        end

        def not_geo_type(value)
          return self if value.blank?

          return not_with_geometry if value.include? 'any'

          geom_type = geom_type_filter_builder(value)

          reflect(
            @query
              .where.not(
                DataCycleCore::Geometry.select(1).arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                  .and(geometry_type(geometries_table[:geom_simple]).in(geom_type))
                ).exists
              )
          )
        end

        def within_shape(value)
          geom = geom_from_encoded_value(value)
          return self if geom.blank?

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(st_intersects(geometries_table[:geom_simple], geom))
              ).exists
            )
          )
        end

        def not_within_shape(value)
          geom = geom_from_encoded_value(value)
          return self if geom.blank?

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(st_intersects(geometries_table[:geom_simple], geom).not)
              ).exists
            )
          )
        end

        private

        def geo_radius_subquery(values)
          return if ((values&.dig('lon').blank? || values&.dig('lat').blank?) && values&.dig('geom').blank?) || values&.dig('distance').blank?

          distance = values['distance'].to_i
          distance *= 1000 if values&.dig('unit') == 'km'
          geometry = if values&.dig('geom').present?
                       st_geom_from_geojson_string(values&.dig('geom'))
                     else
                       st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)
                     end

          st_dwithin(
            cast_geography(geometries_table[:geom_simple]),
            cast_geography(geometry),
            distance
          )
        end

        def geom_from_encoded_value(value)
          return unless value.present? && value.is_a?(Hash)

          shape, type = geo_shape_from_value(value)
          return unless shape.present? && shape.is_a?(String)

          if shape.start_with?('{') && shape.end_with?('}')
            validate_geo_type!(shape, type)
            st_geom_from_geojson_string(shape)
          elsif WKT_LINE_REGEX.match?(shape) || WKT_POLYGON_REGEX.match?(shape)
            validate_geo_type!(shape, type)
            st_geom_from_text(shape)
          elsif type == :polygon
            st_make_polygon(st_line_from_polyline(shape))
          else
            st_line_from_polyline(shape)
          end
        end

        def geo_shape_from_value(value)
          return unless value.is_a?(Hash)

          value = value.deep_stringify_keys
          if value['polygon'].present?
            return value['polygon'], :polygon
          elsif value['line'].present?
            return value['line'], :line
          end
        end

        def validate_geo_type!(value, type)
          return if TYPE_VALIDATIONS[type].match?(value.to_s)

          raise DataCycleCore::Error::Api::BadRequestError.new({ parameter_path: type.to_s, type: 'wrong_geo_type' }), "Invalid geometry type for #{type}"
        end

        def geom_type_filter_builder(value)
          geom_type = []

          value = value.map(&:downcase)

          geom_type.concat(POINT_TYPES) if value.include? 'point'
          geom_type.concat(LINE_TYPES) if value.include? 'line'
          geom_type.concat(POLYGON_TYPES) if value.include? 'polygon'

          geom_type
        end
      end
    end
  end
end
