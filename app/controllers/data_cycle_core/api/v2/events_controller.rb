# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class EventsController < DataCycleCore::Api::V2::ContentsController
        def index
          query = build_search_query

          if permitted_params&.dig(:filter, :from).present?
            query = query.event_from_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :from)))
          else
            query = query.event_from_time(Time.zone.now)
          end

          if permitted_params&.dig(:filter, :to).present?
            query = query.event_end_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :to)))
          end

          @pagination_contents = apply_paging(query.sort_by_proximity)
          @contents = @pagination_contents
        end

        def permitted_parameter_keys
          super + [{ filter: [:from, :to, { classifications: [] }] }]
        end
      end
    end
  end
end
