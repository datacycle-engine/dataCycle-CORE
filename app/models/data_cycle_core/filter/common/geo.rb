# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Geo
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
          return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

          distance = values['distance'].to_i
          distance *= 1000 if values&.dig('unit') == 'km'

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(
                  st_dwithin(
                    cast_geography(geometries_table[:geom_simple]),
                    cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)),
                    distance
                  )
                )
              ).exists
            )
          )
        end

        def not_geo_radius(values)
          return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

          distance = values['distance'].to_i
          distance *= 1000 if values&.dig('unit') == 'km'

          reflect(
            @query.where(
              DataCycleCore::Geometry.select(1).arel
              .where(
                geometries_table[:thing_id].eq(thing[:id])
                .and(geometries_table[:is_primary].eq(true))
                .and(
                  st_dwithin(
                    cast_geography(geometries_table[:geom_simple]),
                    cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)),
                    distance
                  ).not
                )
              ).exists
            )
          )
        end

        def geo_within_classification(ids)
          return self if ids.blank?

          reflect(
            @query
              .where(
                DataCycleCore::Geometry.select(1).joins('CROSS JOIN "classification_polygons"').arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                  .and(classification_polygon[:classification_alias_id].in(ids))
                  .and(st_intersects(classification_polygon[:geom], geometries_table[:geom_simple]))
                ).exists
              )
          )
        end

        def not_geo_within_classification(ids)
          return self if ids.blank?

          reflect(
            @query
              .where(
                DataCycleCore::Geometry.select(1).joins('CROSS JOIN "classification_polygons"').arel
                .where(
                  geometries_table[:thing_id].eq(thing[:id])
                  .and(geometries_table[:is_primary].eq(true))
                  .and(classification_polygon[:classification_alias_id].in(ids))
                  .and(st_intersects(classification_polygon[:geom], geometries_table[:geom_simple]).not)
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

        private

        def geom_type_filter_builder(value)
          geom_type = []

          value = value.map(&:downcase)

          if value.include? 'point'
            geom_type << 'POINT'
            geom_type << 'MULTIPOINT'
          end

          if value.include? 'line'
            geom_type << 'LINESTRING'
            geom_type << 'MULTILINESTRING'
          end

          if value.include? 'polygon'
            geom_type << 'POLYGON'
            geom_type << 'MULTIPOLYGON'
          end

          geom_type
        end
      end
    end
  end
end
