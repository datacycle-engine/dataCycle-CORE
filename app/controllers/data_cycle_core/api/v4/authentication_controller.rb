# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class AuthenticationController < ::DataCycleCore::Api::V4::ApiBaseController
        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def login
          @user = User.find_by(email: login_params[:email])

          raise CanCan::AccessDenied, 'invalid_login' unless @user&.valid_password?(params[:password])
          raise CanCan::AccessDenied, 'user_not_allowed' unless @user.can?(:login, :user_api)

          @user.user_groups = (@user.user_groups + DataCycleCore::Feature::UserApi.default_user_groups).uniq unless DataCycleCore::Feature::UserApi.default_user_groups.nil?

          render json: @user.generate_user_token(true).to_h.merge({
            user: @user.as_user_api_json
          }).deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :ok
        end

        def renew_login
          raise CanCan::AccessDenied, 'user_not_allowed' unless can?(:login, :user_api)

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
      end
    end
  end
end
