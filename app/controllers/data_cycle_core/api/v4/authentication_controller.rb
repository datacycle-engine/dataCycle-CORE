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

          @user.update_column(:jti, SecureRandom.uuid)

          @user.user_groups = (@user.user_groups + DataCycleCore::Feature::UserApi.default_user_groups).uniq unless DataCycleCore::Feature::UserApi.default_user_groups.nil?

          valid_until = Time.zone.now + (DataCycleCore.features.dig(:user_api, :expiration_time) || 24.hours)
          token = DataCycleCore::JsonWebToken.encode(payload: { user_id: @user.id, jti: @user.jti }, exp: valid_until)

          render json: {
            token: token,
            exp: valid_until,
            user: @user.as_user_api_json
          }.deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :ok
        end

        def renew_login
          raise CanCan::AccessDenied, 'user_not_allowed' unless can?(:login, :user_api)

          valid_until = Time.zone.now + (DataCycleCore.features.dig(:user_api, :expiration_time) || 24.hours)
          token = DataCycleCore::JsonWebToken.encode(payload: { user_id: current_user.id, jti: current_user.jti }, exp: valid_until)

          render json: {
            token: token,
            exp: valid_until,
            user: current_user.as_user_api_json
          }.deep_transform_keys { |k| k.to_s.camelize(:lower) }, status: :ok
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
