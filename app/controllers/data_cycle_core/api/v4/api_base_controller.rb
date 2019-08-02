# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ApiBaseController < ::DataCycleCore::Api::V2::ApiBaseController
        include ActionController::HttpAuthentication::Token::ControllerMethods

        def permitted_parameter_keys
          [:api_subversion, :token, :content_id, { page: [:size, :number, :offset, :limit], include: [] }]
        end

        private

        def authenticate
          return if current_user

          if request.headers['Authorization'].present?
            authenticate_or_request_with_http_token do |token|
              @decoded = DataCycleCore::JsonWebToken.decode(token)

              raise CanCan::AccessDenied, 'not implemented yet' if @decoded[:iss] != DataCycleCore::JsonWebToken::ISSUER

              @user = User.find_by(id: @decoded[:user_id], jti: @decoded[:jti])
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
