# frozen_string_literal: true

module DataCycleCore
  module Export
    module FeratelIdentityServer
      class Endpoint < DataCycleCore::Export::Common::Endpoint::GenericEndpoint
        AccessToken = Struct.new(:token, :type, :expiration_time)

        attr_reader :client, :host

        def initialize(**options)
          raise 'grant_type cannot be blank' if options.dig(:grant_type).blank?
          raise 'client_options cannot be blank' if options.dig(:client_options).blank?
          raise 'host cannot be blank' if options.dig(:host).blank?

          @host = options.dig(:host)
          @client = Rack::OAuth2::Client.new(options.dig(:client_options).deep_symbolize_keys)

          case options.dig(:grant_type)
          when 'password'
            @client.resource_owner_credentials = options[:username], options[:password]
          when 'authorization_code'
            @client.authorization_code = options[:authorization_code]
          when 'refresh_token'
            @client.refresh_token = options[:refresh_token]
          end
        end

        def access_token
          refresh_access_token if @access_token.nil? || @access_token.expiration_time - 60.seconds <= Time.zone.now

          @access_token
        end

        def create_user(data:, external_system_data: {})
          response = Faraday.new(url: File.join(@host, 'Users')).post do |req|
            req.headers['Authorization'] = [access_token.type, access_token.token].join(' ')
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              name: data.full_name,
              username: data.full_name&.underscore_blanks,
              email: data.email,
              emailConfirmed: true,
              password: data.raw_password,
              hasPassword: true,
              passwordExpired: false,
              active: true,
              role: 3
            }.to_json
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{File.join(@host, 'Users')}, external_system_data: #{external_system_data}", response) unless response.success?

          JSON.parse(response.body)&.dig('result')
        end

        def update_user(data:, external_system_data: {})
          response = Faraday.new(url: File.join(@host, 'Users', data.uid)).put do |req|
            req.headers['Authorization'] = [access_token.type, access_token.token].join(' ')
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              id: data.uid,
              name: data.full_name,
              email: data.email,
              emailConfirmed: true
            }.to_json
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error sending data to #{File.join(@host, 'Users', data.uid)}, external_system_data: #{external_system_data}", response) unless response.success?

          JSON.parse(response.body)&.dig('result')
        end

        private

        def refresh_access_token
          return if @client.blank?

          token = @client.access_token!
          @access_token = AccessToken.new(token.access_token, token.token_type, (Time.zone.now + token.expires_in.seconds))
        end
      end
    end
  end
end
