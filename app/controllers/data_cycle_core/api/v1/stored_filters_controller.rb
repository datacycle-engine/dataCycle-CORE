module DataCycleCore
  module Api
    module V1
      class StoredFiltersController < Api::V1::ApiBaseController
        include DataCycleCore::Filter

        def show
          @contents = apply_filter(filter_id: permitted_params[:id], api_only: true).page(permitted_params[:page]).includes(content_data: [:classifications, :translations, :watch_lists]).map(&:content_data)
        end

        private

        def permitted_parameter_keys
          super + [:id]
        end
      end
    end
  end
end
