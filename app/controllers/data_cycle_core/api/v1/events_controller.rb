# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class EventsController < DataCycleCore::Api::V1::ContentsController
        def index
          filter = DataCycleCore::StoredFilter.new
          filter.language = 'all'
          query = filter.apply
          query = query.schema_type('Event')

          query = query.fulltext_search(permitted_params[:q]) if permitted_params[:q]

          if permitted_params&.dig(:filter, :from)
            query = query.event_from_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :from)))
          else
            query = query.event_from_time(Time.zone.now)
          end

          query = query.event_end_time(DataCycleCore::MasterData::DataConverter.string_to_datetime(permitted_params&.dig(:filter, :to))) if permitted_params&.dig(:filter, :to)

          if permitted_params&.dig(:filter, :classifications)
            permitted_params.dig(:filter, :classifications).map { |classifications|
              classifications.split(',').map(&:strip).compact_blank
            }.reject(&:empty?).each do |classifications|
              query = query.classification_alias_ids_with_subtree(classifications)
            end
          end
          query = query.sort_by_proximity
          @contents = apply_paging(query)
        end

        def show
          @content = DataCycleCore::Thing.with_schema_type('Event').includes(:classifications, :translations).find(permitted_params[:id])
        end

        def permitted_parameter_keys
          super + [:id, :q, { filter: [:from, :to, { classifications: [] }] }]
        end
      end
    end
  end
end
