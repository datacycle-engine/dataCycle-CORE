# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class PlacesController < DataCycleCore::Api::V2::ContentsController
        def index
          query = build_search_query

          if permitted_params&.dig(:filter, :box).present? && permitted_params&.dig(:filter, :box)&.split(',')&.size == 4
            query = query.within_box(*permitted_params[:filter][:box].split(',').map(&:to_f))
          end

          @pagination_contents = apply_paging(query)
          @contents = @pagination_contents.map(&:content_data)
        end

        def permitted_parameter_keys
          super + [{ filter: [:box, { classifications: [] }] }]
        end
      end
    end
  end
end
