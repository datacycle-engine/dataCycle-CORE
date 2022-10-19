# frozen_string_literal: true

module DataCycleCore
  class ApiTokenStrategy < Warden::Strategies::Base
    def valid?
      params[:token].present?
    end

    def authenticate!
      authenticate_with_token(params[:token])
    end

    def store?
      false
    end

    private

    def authenticate_with_token(token)
      request.env['devise.skip_trackable'] = true

      user = User.find_by(access_token: token)
      return success!(user) unless user.nil?

      decoded = DataCycleCore::JsonWebToken.decode(token)
      user = DataCycleCore::User.find_with_token(decoded)
      decoded['iss'].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }
      decoded['original_iss'].presence&.then { |i| request.env['data_cycle.feature.user_api.issuer'] = i }
      user.nil? ? fail!('invalid authentication token') : success!(user)
    rescue JSON::ParserError, JWT::DecodeError
      fail!('invalid authentication token')
    end
  end
end
