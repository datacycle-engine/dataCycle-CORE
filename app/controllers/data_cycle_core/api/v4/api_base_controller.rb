# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ApiBaseController < ::DataCycleCore::Api::V2::ApiBaseController
        include ActionController::HttpAuthentication::Token::ControllerMethods

        def permitted_parameter_keys
          [:api_subversion, :token, :include, :fields, :content_id, { page: [:size, :number, :offset, :limit] }]
        end

        def parse_tree_params(raw_params)
          return [] if raw_params&.strip.blank?
          raw_params.split(',')&.map(&:strip)&.map { |item| item.split('.')&.map(&:strip) }
        end

        def parse_language(language_string)
          return nil if language_string&.strip.blank?
          language_string.split(',')&.map(&:strip)
        end

        private

        def request_http_token_authentication(realm = 'Application', _message = nil)
          headers['WWW-Authenticate'] = %(Token realm="#{realm.delete('"')}")
          raise CanCan::AccessDenied, 'HTTP Token: Access denied.'
        end

        def authenticate
          return if current_user

          if request.headers['Authorization'].present?
            authenticate_or_request_with_http_token do |token|
              @decoded = DataCycleCore::JsonWebToken.decode(token)
              @user = DataCycleCore::User.find_with_token(@decoded)
            rescue JWT::DecodeError, JSON::ParserError => e
              raise CanCan::AccessDenied, e.message
            end
          elsif params[:token].present?
            @user = User.find_by(access_token: params[:token])
          end

          raise CanCan::AccessDenied, 'invalid or missing authentication token' if @user.nil?

          sign_in @user, store: false
        end
      end
    end
  end
end
