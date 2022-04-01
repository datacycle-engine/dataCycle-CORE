# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GoogleBusiness
      class Endpoint
        AccessToken = Struct.new(:token, :type, :expiration_time)

        attr_reader :client_id, :client_secret, :refresh_token

        def initialize(client_id:, client_secret:, refresh_token:, **_options)
          raise 'client_id cannot be blank' if client_id.blank?
          raise 'client_secret cannot be blank' if client_secret.blank?
          raise 'refresh_token cannot be blank' if refresh_token.blank?

          @client_id = client_id
          @client_secret = client_secret
          @refresh_token = refresh_token
        end

        def access_token
          refresh_access_token if @access_token.nil? || @access_token.expiration_time - 60.seconds <= Time.zone.now

          @access_token
        end

        def accounts(lang: nil)
          Enumerator.new do |yielder|
            next_page_token = nil

            loop do
              data = load_accounts(next_page_token: next_page_token, lang: lang)

              (data['accounts'] || []).each do |account_data|
                yielder << account_data
              end

              next_page_token = data['nextPageToken']

              break if next_page_token.blank?
            end
          end
        end

        def locations(lang: :de)
          Enumerator.new do |yielder|
            accounts.each do |account|
              next_page_token = nil

              loop do
                data = load_locations(account['name'], next_page_token: next_page_token, lang: lang)

                (data['locations'] || []).each do |location_data|
                  yielder << location_data if location_data['languageCode'] == lang.to_s
                end

                next_page_token = data['nextPageToken']

                break if next_page_token.blank?
              end
            end
          end
        end

        private

        def load_accounts(next_page_token:, lang:) # rubocop:disable Lint/UnusedMethodArgument
          load_data('https://mybusiness.googleapis.com/v4/accounts', next_page_token: next_page_token, lang: nil)
        end

        def load_locations(account_path, next_page_token:, lang:)
          load_data("https://mybusiness.googleapis.com/v4/#{account_path}/locations", next_page_token: next_page_token, lang: lang)
        end

        def load_data(url, next_page_token:, lang:)
          response = Faraday.new(url: url).get do |req|
            req.headers['Authorization'] = [access_token.type, access_token.token].join(' ')
            req.params['pageToken'] = next_page_token if next_page_token.present?
            req.params['languageCode'] = lang if lang.present?
          end

          raise "Error connecting to '#{response.env.url.host}'" unless response.success?

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

          raise "Error connecting to '#{response.env.url.host}'" unless response.success?

          data = JSON.parse(response.body)

          @access_token = AccessToken.new(data['access_token'], data['token_type'], (Time.zone.now + data['expires_in'].seconds))
        end
      end
    end
  end
end
