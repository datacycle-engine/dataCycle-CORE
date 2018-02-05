module DataCycleCore
  module Api
    module V1
      class StoredFiltersController < Api::V1::ApiBaseController
        include DataCycleCore::Filter

        def show
          @contents = apply_filter(filter_id: params[:id], api_only: true)
        end
      end
    end
  end
end
