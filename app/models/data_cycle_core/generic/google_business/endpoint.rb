# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GoogleBusiness
      class Endpoint
        AccessToken = Struct.new(:token, :type, :expiration_time)

        attr_reader :client_id, :client_secret, :refresh_token

        def initialize(client_id:, client_secret:, refresh_token:, **_options)
          @client_id = client_id
          @client_secret = client_secret
          @refresh_token = refresh_token
        end

        def access_token
          if @access_token.nil? || @access_token.expiration_time - 60.seconds <= Time.zone.now
            refresh_access_token
          end

          @access_token
        end

        def accounts
          Enumerator.new do |yielder|
            next_page_token = nil

            loop do
              data = load_accounts(next_page_token: next_page_token)

              data['accounts'].each do |account_data|
                yielder << account_data
              end

              next_page_token = data['nextPageToken']

              break if next_page_token.blank?
            end
          end
        end

        def locations
          Enumerator.new do |yielder|
            accounts.each do |account|
              next_page_token = nil

              loop do
                data = load_locations(account['name'], next_page_token: next_page_token)

                data['locations'].each do |location_data|
                  yielder << location_data
                end

                next_page_token = data['nextPageToken']

                break if next_page_token.blank?
              end
            end
          end
        end

        private

        def load_accounts(next_page_token:)
          load_data('https://mybusiness.googleapis.com/v4/accounts', next_page_token: next_page_token)
        end

        def load_locations(account_path, next_page_token:)
          load_data("https://mybusiness.googleapis.com/v4/#{account_path}/locations", next_page_token: next_page_token)
        end

        def load_data(url, next_page_token:)
          response = Faraday.new(url: url).get do |req|
            req.headers['Authorization'] = [access_token.type, access_token.token].join(' ')
            req.params['pageToken'] = next_page_token if next_page_token.present?
          end

          JSON.parse(response.body)
        end

        def refresh_access_token
          response = Faraday.new(url: 'https://www.googleapis.com/oauth2/v3/token').post do |req|
            req.params['client_id'] = client_id
            req.params['client_secret'] = client_secret
            req.params['refresh_token'] = refresh_token
            req.params['grant_type'] = 'refresh_token'
            req.params['access_type'] = 'offline'
          end

          data = JSON.parse(response.body)

          @access_token = AccessToken.new(data['access_token'], data['token_type'], (Time.zone.now + data['expires_in'].seconds))
        end
      end
    end
  end
end
