# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Type
      module Place
        def within_box(sw_lon, sw_lat, ne_lon, ne_lat)
          query = join_place
            .where(contains(place[:location], get_box(get_point(sw_lon, sw_lat), get_point(ne_lon, ne_lat))).eq('true'))

          reflect(@query.where(search[:content_data_id].in(query)))
        end

        private

        def join_place
          Arel::SelectManager.new
            .project(search[:content_data_id])
            .from(search)
            .join(place)
            .on(search[:content_data_id].eq(place[:id]).and(search[:schema_type].eq(quoted('Place'))))
        end

        def place
          DataCycleCore::Thing.arel_table
        end
      end
    end
  end
end
