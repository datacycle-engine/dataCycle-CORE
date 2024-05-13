# frozen_string_literal: true

module DataCycleCore
  module Api
    module V1
      class StoredFiltersController < Api::V1::ApiBaseController
        include DataCycleCore::FilterConcern

        def show
          apply_filter(filter_id: permitted_params[:id], api_only: true)

          raise ActiveRecord::RecordNotFound unless (@stored_filter.shared_users.pluck(:id) + [@stored_filter.user_id]).include?(current_user.id)

          @language = @stored_filter.language

          query = @stored_filter.apply
          query = query.page(permitted_params[:page])

          @contents = query.includes(:classifications, :translations, :watch_lists)
          @total = @contents.total_count
        end

        private

        def permitted_parameter_keys
          super + [:id]
        end
      end
    end
  end
end
