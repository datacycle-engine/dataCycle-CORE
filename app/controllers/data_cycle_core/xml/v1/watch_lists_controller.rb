# frozen_string_literal: true

module DataCycleCore
  module Xml
    module V1
      class WatchListsController < ::DataCycleCore::Xml::V1::ContentsController
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
          @watch_lists
        end

        def show
          @watch_list = DataCycleCore::WatchList.find(permitted_params[:id])
          @pagination_contents = @watch_list.watch_list_data_hashes.order(created_at: :desc)
          @contents = @pagination_contents
        end

        private

        def permitted_parameter_keys
          super + [:user_email, :id]
        end
      end
    end
  end
end
