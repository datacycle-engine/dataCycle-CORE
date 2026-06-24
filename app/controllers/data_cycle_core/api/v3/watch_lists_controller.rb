# frozen_string_literal: true

module DataCycleCore
  module Api
    module V3
      class WatchListsController < ::DataCycleCore::Api::V3::ContentsController
        PUMA_MAX_TIMEOUT = 60
        before_action :prepare_url_parameters
        def index
          @watch_lists = if permitted_params[:user_email].present?
                           target_user = User.find_by(email: permitted_params[:user_email])
                           authorize! :show, target_user unless target_user == current_user
                           DataCycleCore::WatchList
                             .accessible_by(DataCycleCore::Ability.new(target_user, session)).without_my_selection
                         else
                           DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
                         end
          @watch_lists = apply_paging(@watch_lists)
        end

        def show
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            @watch_list = DataCycleCore::WatchList.find(permitted_params[:id])
            authorize! :show, @watch_list
            query = DataCycleCore::Thing.joins(:watch_list_data_hashes).where(watch_list_data_hashes: { watch_list_id: @watch_list.id }).order('watch_list_data_hashes.order_a ASC, watch_list_data_hashes.created_at ASC, things.id DESC')

            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents
            render 'show'
          end
        end

        private

        def permitted_parameter_keys
          super + [:user_email, :id]
        end
      end
    end
  end
end
