# frozen_string_literal: true

module DataCycleCore
  module SyncApi
    module V1
      class WatchListsController < ::DataCycleCore::SyncApi::V1::ContentsController
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
          render json: @watch_lists.map(&:to_hash)
        end

        def show
          redirect_to sync_api_v1_stored_filter_path(permitted_params.except(:id).merge(sl: 1))
        end

        private

        def permitted_parameter_keys
          super + [:user_email, :id, :thing_id]
        end
      end
    end
  end
end
