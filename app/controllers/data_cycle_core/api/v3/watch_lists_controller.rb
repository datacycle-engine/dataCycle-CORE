# frozen_string_literal: true

module DataCycleCore
  module Api
    module V3
      class WatchListsController < ContentsController
        before_action :prepare_url_parameters
        def index
          if permitted_params[:user_email].present?
            @watch_lists = DataCycleCore::WatchList
              .accessible_by(DataCycleCore::Ability.new(User.find_by(email: permitted_params[:user_email]), session))
          else
            @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability)
          end
          @watch_lists = apply_paging(@watch_lists)
        end

        # method to show a particular WatchList
        def show
          @watch_list = DataCycleCore::WatchList.find(permitted_params[:id])
        end

        private

        def permitted_parameter_keys
          super + [:user_email, :id]
        end
      end
    end
  end
end
