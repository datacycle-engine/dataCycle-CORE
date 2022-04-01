# frozen_string_literal: true

module DataCycleCore
  class JsonWebToken
    require 'jwt'
    ALGORITHMS = ['HS256', 'RS256'].freeze
    SECRET_KEY = Rails.application.secrets.secret_key_base.to_s
    ISSUER = DataCycleCore.features.dig(:user_api, :issuer) || 'datacycle.at'

    def self.encode(payload:, exp: Time.zone.now + (DataCycleCore.features.dig(:user_api, :expiration_time) || 24.hours), alg: 'HS256', key: SECRET_KEY)
      payload[:exp] = exp.to_i
      payload[:iss] = ISSUER
      JWT.encode(payload, key, ALGORITHMS.include?(alg) ? alg : 'HS256')
    end

    def self.decode(token)
      header_fields = JSON.parse(Base64.decode64(token.split('.').first))
      payload = JSON.parse(Base64.decode64(token.split('.')[1]))
      algorithm = header_fields['alg'] if ALGORITHMS.include?(header_fields['alg'])

      if algorithm&.start_with?('RS')
        secret = DataCycleCore.features.dig(:user_api, :public_keys, payload['iss']).present? ? OpenSSL::PKey::RSA.new(DataCycleCore.features.dig(:user_api, :public_keys, payload['iss'])) : nil
      else
        secret = SECRET_KEY
      end

      raise JWT::DecodeError, 'secret cannot be blank' if secret.blank?

      decoded = JWT.decode(token, secret, true, { algorithm: algorithm }).first
      HashWithIndifferentAccess.new decoded
    end
  end
end
