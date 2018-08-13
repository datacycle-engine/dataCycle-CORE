# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class StoredFiltersController < Api::V1::ApiBaseController
        include DataCycleCore::Filter

        def show
          @stored_filter = DataCycleCore::StoredFilter.find(permitted_params[:id])

          raise ActiveRecord::RecordNotFound unless (@stored_filter.api_users + [@stored_filter.user_id]).include?(current_user.id)

          query = apply_filter(filter_id: permitted_params[:id], api_only: true).page(permitted_params[:page]).includes(content_data: [:classifications, :translations, :watch_lists])
          @contents = query.map(&:content_data)
          @total = query.total_count
        end

        private

        def permitted_parameter_keys
          super + [:id]
        end
      end
    end
  end
end
