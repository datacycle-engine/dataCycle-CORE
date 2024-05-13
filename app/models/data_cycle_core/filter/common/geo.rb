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
          filter_type = "not_#{type}".to_sym
          raise 'Unknown geo filter' unless respond_to?(filter_type)
          send(filter_type, value)
        end

        def within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

          reflect(
            @query.where(
              intersects(thing[:geom_simple], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326))
            )
          )
        end

        def not_within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

          reflect(
            @query.where.not(
              intersects(thing[:geom_simple], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326))
            )
          )
        end

        def geo_radius(values)
          return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

          distance = values['distance'].to_i
          distance *= 1000 if values&.dig('unit') == 'km'
          thing_alias = thing.alias

          reflect(
            @query
              .where.not(thing[:geom_simple].eq(nil))
              .where(
                DataCycleCore::Thing.select(1).arel
                .from(thing_alias)
                .where(
                  thing[:id].eq(thing_alias[:id])
                  .and(
                    st_dwithin(
                      cast_geography(thing_alias[:geom_simple]),
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
          thing_alias = thing.alias

          reflect(
            @query
              .where.not(thing[:geom_simple].eq(nil))
              .where.not(
                DataCycleCore::Thing.select(1).arel
                .from(thing_alias)
                .where(
                  thing[:id].eq(thing_alias[:id])
                  .and(
                    st_dwithin(
                      cast_geography(thing_alias[:geom_simple]),
                      cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)),
                      distance
                    )
                  )
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
            sub_query = Arel::SelectManager.new
              .project(classification_polygon[:geom])
              .from(classification_polygon)
              .where(classification_polygon[:classification_alias_id].eq(id))

            contains_queries << st_intersects(sub_query, thing[:geom_simple])
          end

          reflect(
            @query
              .where(
                contains(thing[:geom_simple], st_makeenvelope(-180.0, -90.0, 180.0, 90.0, 4326))
              )
            .where(contains_queries.reduce(:or))
          )
        end

        def not_geo_within_classification(ids)
          return self if ids.blank?

          contains_queries = []
          ids.each do |id|
            sub_query = Arel::SelectManager.new
              .project(classification_polygon[:geom])
              .from(classification_polygon)
              .where(classification_polygon[:classification_alias_id].eq(id))

            contains_queries << st_disjoint(sub_query, thing[:geom_simple])
          end

          reflect(
            @query
              .where(
                contains(thing[:geom_simple], st_makeenvelope(-180.0, -90.0, 180.0, 90.0, 4326))
              )
              .where(contains_queries.reduce(:or))
          )
        end

        def with_geometry
          reflect(
            @query
              .where.not(
                thing[:geom_simple].eq(nil)
              )
          )
        end

        def not_with_geometry
          reflect(
            @query
              .where(
                thing[:geom_simple].eq(nil)
              )
          )
        end

        def geo_type(value)
          return self if value.blank?

          return with_geometry if value.include? 'any'

          geom_type = geom_type_filter_builder(value)

          @query = @query.where(
            'GeometryType(geom_simple) IN (?)', geom_type
          )

          reflect(@query)
        end

        def not_geo_type(value)
          return self if value.blank?

          return not_with_geometry if value.include? 'any'

          geom_type = geom_type_filter_builder(value)

          reflect(
            @query
              .where(
                'GeometryType(geom_simple) NOT IN (?)', geom_type
              )
          )
        end

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
