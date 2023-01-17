# frozen_string_literal: true

module DataCycleCore
  class JsonWebToken
    require 'jwt'
    ALGORITHMS = ['HS256', 'RS256'].freeze

    Token = Struct.new(:token, :exp)

    def self.encode(payload:, exp: DataCycleCore::Feature::UserApi.expires, alg: 'HS256', key: DataCycleCore::Feature::UserApi.secret_key)
      payload[:exp] = exp.to_i
      payload[:iss] = DataCycleCore::Feature::UserApi.issuer if payload[:iss].blank?

      Token.new(JWT.encode(payload, key, ALGORITHMS.include?(alg) ? alg : 'HS256'), exp)
    end

    def self.decode(token)
      return {} if token.blank?

      header_fields = JSON.parse(Base64.decode64(token.split('.').first))
      payload = JSON.parse(Base64.decode64(token.split('.')[1]))
      algorithm = header_fields['alg'] if ALGORITHMS.include?(header_fields['alg'])
      secret = DataCycleCore::Feature::UserApi.secret_for_issuer(payload['iss'])

      raise JWT::DecodeError, 'secret cannot be blank' if secret.blank?

      decoded = JWT.decode(token, secret, true, { algorithm: algorithm }).first
      HashWithIndifferentAccess.new decoded
    end
  end
end
