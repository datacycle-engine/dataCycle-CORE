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
              intersects(thing[:location], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326))
              .or(intersects(thing[:line], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326)))
            )
          )
        end

        def not_within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

          reflect(
            @query.where.not(
              intersects(thing[:location], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326))
              .and(intersects(thing[:line], st_makeenvelope(sw_lon.to_f, sw_lat.to_f, ne_lon.to_f, ne_lat.to_f, 4326)))
            )
          )
        end

        def geo_radius(values)
          return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

          reflect(
            @query
              .where(
                st_dwithin(cast_geography(thing[:location]), cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)), values&.dig('distance').to_i)
                .or(st_dwithin(cast_geography(thing[:line]), cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)), values&.dig('distance').to_i))
              )
          )
        end

        def not_geo_radius(values)
          return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

          reflect(
            @query
              .where.not(
                st_dwithin(cast_geography(thing[:location]), cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)), values&.dig('distance').to_i)
                .and(st_dwithin(cast_geography(thing[:line]), cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)), values&.dig('distance').to_i))
              )
          )
        end

        def geo_within_classification(ids)
          return self if ids.blank?

          contains_queries = []
          ids.each do |id|
            sub_query = Arel::SelectManager.new
              .project(classification_polygon[:geom])
              .from(classification_polygon)
              .where(classification_polygon[:classification_alias_id].eq(id))

            contains_queries << st_intersects(sub_query, st_transform(thing[:location], 3035))
            # contains_queries << st_intersects(sub_query, st_transform(thing[:line], 3035))
          end

          reflect(
            @query
              .where(
                contains(thing[:location], st_makeenvelope(-90.0, -180.0, 90.0, 180.0, 4326))
                # .or(contains(thing[:line], st_makeenvelope(-90.0, -180.0, 90.0, 180.0, 4326)))
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

            contains_queries << st_disjoint(sub_query, st_transform(thing[:location], 3035))
            # contains_queries << st_disjoint(sub_query, st_transform(thing[:line], 3035))
          end

          reflect(
            @query
              .where(
                contains(thing[:location], st_makeenvelope(-90.0, -180.0, 90.0, 180.0, 4326))
                # .or(contains(thing[:line], st_makeenvelope(-90.0, -180.0, 90.0, 180.0, 4326)))
              )
              .where(contains_queries.reduce(:or))
          )
        end
      end
    end
  end
end
