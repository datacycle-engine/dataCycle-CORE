# frozen_string_literal: true

module DataCycleCore
  module SyncApi
    module V1
      class WatchListsController < ::DataCycleCore::SyncApi::V1::ContentsController
        before_action :prepare_url_parameters

        def index
          if permitted_params[:user_email].present?
            @watch_lists = DataCycleCore::WatchList
              .accessible_by(DataCycleCore::Ability.new(User.find_by(email: permitted_params[:user_email]), session)).without_my_selection
          else
            @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
          end
          # @watch_lists = apply_paging(@watch_lists)
          render json: @watch_lists.map(&:to_hash)
        end

        # method to show a particular WatchList
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
