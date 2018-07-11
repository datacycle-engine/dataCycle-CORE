# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class EventsController < DataCycleCore::Api::V2::ContentsController
        def index
          query = Event.includes(:translations, :classifications).with_content_type('entity')
          query = filter_query(query)
          @contents = apply_paging(query).sort_by_proximity
        end

        def permitted_parameter_keys
          super + [{ filter: [:from, :to, { classifications: [] }] }]
        end
      end
    end
  end
end
