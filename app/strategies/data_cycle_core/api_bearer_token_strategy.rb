# frozen_string_literal: true

module DataCycleCore
  class ApiBearerTokenStrategy < DataCycleCore::ApiTokenStrategy
    include ActionController::HttpAuthentication::Token::ControllerMethods

    def valid?
      ActionController::HttpAuthentication::Token.token_and_options(request).present?
    end

    def authenticate!
      authenticate_or_request_with_http_token do |token|
        authenticate_with_token(token)
      end
    end
  end
end
