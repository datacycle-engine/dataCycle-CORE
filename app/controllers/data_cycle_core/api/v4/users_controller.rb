# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class UsersController < ::DataCycleCore::Api::V4::ContentsController
        before_action :prepare_url_parameters
        skip_before_action :authenticate, only: :create

        def index
          @user_data = current_user
          @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability)
          @stored_filter = DataCycleCore::StoredFilter.accessible_by(current_ability).where("'#{current_user.id}' = ANY (api_users)")
        end

        def create
          @user = ('DataCycleCore::' + controller_name.singularize.classify).constantize.new(permitted_params)
          @user.access_token = SecureRandom.hex

          if @user.save
            render json: @user
          else
            render json: { errors: @user.errors }
          end
        end

        private

        def permitted_params
          params.require(controller_name.singularize.to_sym).permit(:email, :family_name, :given_name, :name, :notification_frequency, :default_locale, :password, :password_confirmation, :current_password)
        end
      end
    end
  end
end
