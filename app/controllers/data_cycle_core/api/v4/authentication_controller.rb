# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class AuthenticationController < ::DataCycleCore::Api::V4::ApiBaseController
        skip_before_action :authenticate_user!, only: :login
        prepend_before_action :authenticate_user_by_params!, only: :login
        before_action :check_user_api_permissions

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def login
          current_user.user_groups = (current_user.user_groups + DataCycleCore::Feature::UserApi.default_user_groups).uniq unless DataCycleCore::Feature::UserApi.default_user_groups.nil?

          render json: current_user.generate_user_token(true).to_h.merge({
            user: current_user.as_user_api_json
          }).deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :ok
        end

        def renew_login
          render json: current_user.generate_user_token.to_h.merge({
            user: current_user.as_user_api_json
          }).deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :ok
        end

        def logout
          current_user.update_column(:jti, nil)

          head :no_content
        end

        private

        def login_params
          params.permit(:email, :password)
        end

        def check_user_api_permissions
          raise CanCan::AccessDenied, 'user_not_allowed' unless can?(:login, :user_api)
        end

        def authenticate_user_by_params!
          user = User.find_by(email: login_params[:email])
          raise CanCan::AccessDenied, 'invalid_login' unless user&.valid_password?(login_params[:password])

          sign_in(user, store: false)
        end
      end
    end
  end
end
