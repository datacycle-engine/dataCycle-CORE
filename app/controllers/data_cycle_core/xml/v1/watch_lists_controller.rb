# frozen_string_literal: true

module DataCycleCore
  module Xml
    module V1
      class WatchListsController < ::DataCycleCore::Xml::V1::ContentsController
        before_action :prepare_url_parameters
        def index
          if permitted_params[:user_email].present?
            @watch_lists = DataCycleCore::WatchList
              .accessible_by(DataCycleCore::Ability.new(User.find_by(email: permitted_params[:user_email]), session)).without_my_selection
          else
            @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
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
