# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Type
      module Event
        def event_end_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          query = join_event.where(event[:start_date].lteq(Arel::Nodes.build_quoted(time.iso8601)))

          reflect(@query.where(search[:content_data_id].in(query)))
        end

        def event_from_time(time)
          time = DataCycleCore::MasterData::DataConverter.string_to_datetime(time)
          query = join_event.where(event[:end_date].gteq(Arel::Nodes.build_quoted(time.iso8601)))

          reflect(@query.where(search[:content_data_id].in(query)))
        end

        def sort_by_proximity(date = Time.zone.now)
          search_query = @query
          DataCycleCore::Filter::Search.new(@locale, DataCycleCore::Thing)
            .where(event[:id].in(search_query.map(&:content_data_id)))
            .order(absolute_date_diff(event[:end_date], Arel::Nodes.build_quoted(date.iso8601)),
                   absolute_date_diff(event[:start_date], Arel::Nodes.build_quoted(date.iso8601)),
                   event[:start_date])
        end

        private

        def join_event
          Arel::SelectManager.new
            .project(search[:content_data_id])
            .from(search)
            .join(event)
            .on(search[:content_data_id].eq(event[:id]).and(search[:content_data_type].eq(quoted('DataCycleCore::Thing'))))
        end

        def event
          DataCycleCore::Thing.arel_table
        end
      end
    end
  end
end
