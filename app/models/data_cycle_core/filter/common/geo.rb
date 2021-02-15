# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Geo
        def within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

          reflect(
            @query.where(contains(thing[:location], get_box(get_point(sw_lon.to_f, sw_lat.to_f), get_point(ne_lon.to_f, ne_lat.to_f))).eq('true'))
          )
        end

        def not_within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          return self if sw_lon.blank? || sw_lat.blank? || ne_lon.blank? || ne_lat.blank?

          reflect(
            @query.where.not(contains(thing[:location], get_box(get_point(sw_lon.to_f, sw_lat.to_f), get_point(ne_lon.to_f, ne_lat.to_f))).eq('true'))
          )
        end

        def geo_radius(values)
          return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

          reflect(
            @query.where(st_dwithin(cast_geography(thing[:location]), cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)), values&.dig('distance').to_i))
          )
        end

        def not_geo_radius(values)
          return self if values&.dig('lon').blank? || values&.dig('lat').blank? || values&.dig('distance').blank?

          reflect(
            @query.where.not(st_dwithin(cast_geography(thing[:location]), cast_geography(st_setsrid(st_makepoint(values&.dig('lon').to_s, values&.dig('lat').to_s), 4326)), values&.dig('distance').to_i))
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

            contains_queries << st_contains(sub_query, st_transform(thing[:location], 3035))
          end

          reflect(
            @query
              .where(overlap(get_box(get_point(-90, -180), get_point(90, 180)), thing[:location]))
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
          end

          reflect(
            @query.where(contains_queries.reduce(:or))
          )
        end
      end
    end
  end
end
