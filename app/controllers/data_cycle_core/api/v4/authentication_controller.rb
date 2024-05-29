# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class AuthenticationController < ::DataCycleCore::Api::V4::ApiBaseController
        # prepend_before_action :force_email_password_authentication!, only: :login
        before_action :set_original_issuer, only: :login
        before_action :init_user_api_feature, except: :check_credentials

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def check_credentials
          render json: { success: true }, status: :ok
        end

        def login
          current_user.user_groups = (current_user.user_groups + current_user.user_api_feature.default_user_groups).uniq if current_user.user_api_feature.default_user_groups.present?

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

        def init_user_api_feature
          raise CanCan::AccessDenied, 'user_not_allowed' unless can?(:login, :user_api)

          current_user.user_api_feature.current_issuer ||= request.env['data_cycle.feature.user_api.issuer']
        end

        # def force_email_password_authentication!
        #   request.env['warden.force_strategy'] = :email_password
        # end

        def set_original_issuer
          token = ActionController::HttpAuthentication::Token.token_and_options(request)&.first

          return if token.blank?

          decoded = DataCycleCore::JsonWebToken.decode(token)

          return if decoded.blank?

          current_user.user_api_feature.current_issuer ||= decoded['original_iss'].presence || decoded['iss'].presence
        rescue JSON::ParserError, JWT::DecodeError
          nil
        end
      end
    end
  end
end
