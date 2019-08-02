# frozen_string_literal: true

module DataCycleCore
  class JsonWebToken
    require 'jwt'
    ALGORITHMS = ['HS256', 'RS256'].freeze
    SECRET_KEY = Rails.application.secrets.secret_key_base.to_s
    PUBLIC_KEYS = DataCycleCore.features.dig(:user_api, :public_keys) || {}
    ISSUER = DataCycleCore.features.dig(:user_api, :issuer) || 'datacycle.at'

    def self.encode(payload, exp = 24.hours.from_now)
      payload[:exp] = exp.to_i
      payload[:iss] = ISSUER
      JWT.encode(payload, SECRET_KEY, ALGORITHMS.first)
    end

    def self.decode(token)
      header_fields = JSON.parse(Base64.decode64(token.split('.').first))
      payload = JSON.parse(Base64.decode64(token.split('.')[1]))
      algorithm = header_fields['alg'] if ALGORITHMS.include?(header_fields['alg'])
      secret = SECRET_KEY
      secret = OpenSSL::PKey::RSA.new(PUBLIC_KEYS[payload['iss']]) if algorithm&.start_with?('RS') && PUBLIC_KEYS[payload['iss']].present?

      decoded = JWT.decode(token, secret, true, { algorithm: algorithm }).first
      HashWithIndifferentAccess.new decoded
    end
  end
end
