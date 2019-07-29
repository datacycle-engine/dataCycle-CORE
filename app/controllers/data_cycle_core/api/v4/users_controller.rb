# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UsersController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters
        def index
          @user_data = current_user
          @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability)
          @stored_filter = DataCycleCore::StoredFilter.accessible_by(current_ability).where("'#{current_user.id}' = ANY (api_users)")
        end
      end
    end
  end
end
