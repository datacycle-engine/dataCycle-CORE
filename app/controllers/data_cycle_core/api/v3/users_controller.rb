# frozen_string_literal: true

module DataCycleCore
  module Api
    module V3
      class UsersController < ::DataCycleCore::Api::V3::ContentsController
        before_action :prepare_url_parameters
        def index
          @user_data = current_user
          @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability).without_my_selection
          @stored_filter = DataCycleCore::StoredFilter.accessible_by(current_ability, :api).named
        end
      end
    end
  end
end
