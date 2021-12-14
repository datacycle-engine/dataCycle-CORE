# frozen_string_literal: true

module DataCycleCore
  module Geojson
    module V1
      class GeojsonBaseController < ::DataCycleCore::Api::V4::ApiBaseController
        include ActionController::HttpAuthentication::Basic::ControllerMethods

        def prepare_url_parameters
          @language = parse_language(permitted_params.dig(:language)).presence || Array(I18n.available_locales.first.to_s)
          @api_version = 1
        end

        private

        def authenticate
          return if current_user # Basic Auth handled by Devise

          if ActionController::HttpAuthentication::Basic.has_basic_credentials?(request)
            authenticate_or_request_with_http_basic do |user_name, password|
              @user = DataCycleCore::User.find_by(email: user_name)
              raise CanCan::AccessDenied, 'invalid credentials' if @user.nil? || !@user.valid_password?(password)
              return sign_in @user, store: false
            end
          elsif ActionController::HttpAuthentication::Token.token_and_options(request).present?
            authenticate_or_request_with_http_token do |token|
              @user = DataCycleCore::User.find_with_token(token: token)
              return sign_in @user, store: false unless @user.nil?

              @decoded = DataCycleCore::JsonWebToken.decode(token)
              @user = DataCycleCore::User.find_with_token(@decoded)
            rescue JSON::ParserError, JWT::DecodeError => e
              raise CanCan::AccessDenied, e.message
            end
          elsif params[:token].present?
            @user = User.find_by(access_token: params[:token])
          end

          raise CanCan::AccessDenied, 'invalid or missing authentication token' if @user.nil?

          request.env['devise.skip_trackable'] = true
          sign_in @user, store: false
        end
      end
    end
  end
end
