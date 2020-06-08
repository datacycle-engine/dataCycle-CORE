# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelIdentityServer
      class Endpoint
        AccessToken = Struct.new(:token, :type, :expiration_time)

        attr_reader :client_options, :host, :pages

        def initialize(client_options:, host:, **_options)
          raise 'client_options cannot be blank' if client_options.blank?
          raise 'host cannot be blank' if host.blank?

          @host = host
          @client_options = client_options
        end

        def access_token
          refresh_access_token if @access_token.nil? || @access_token.expiration_time - 60.seconds <= Time.zone.now

          @access_token
        end

        def users(lang: nil)
          Enumerator.new do |yielder|
            next_page = 1

            loop do
              data = load_data(File.join(@host, '/Users'), next_page: next_page, lang: lang, additional_params: { userType: 3 })

              (data || []).each do |data_hash|
                full_data_hash = load_single_data(File.join(@host, '/Users', data_hash['id']))
                yielder << full_data_hash.deep_transform_keys { |k| k.tr('.', '-') }
              end

              next_page += 1

              break if next_page > pages
            end
          end
        end

        def claims(lang: nil)
          download_data(path: '/Claims', lang: lang)
        end

        def realms(lang: nil)
          download_data(path: '/Realms', lang: lang)
        end

        def clients(lang: nil)
          download_data(path: '/Clients', lang: lang)
        end

        def scopes(lang: nil)
          download_data(path: '/Scopes', lang: lang)
        end

        def tokens(lang: nil)
          download_data(path: '/Tokens', lang: lang)
        end

        def download_data(path:, lang: nil)
          Enumerator.new do |yielder|
            next_page = 1

            loop do
              data = load_data(File.join(@host, path), next_page: next_page, lang: lang)

              (data || []).each do |data_hash|
                yielder << data_hash
              end

              next_page += 1

              break if next_page > pages
            end
          end
        end

        private

        def load_data(url, next_page:, lang:, additional_params: {}) # rubocop:disable Lint/UnusedMethodArgument
          response = Faraday.new(url: url).get do |req|
            req.headers['Authorization'] = [access_token.type, access_token.token].join(' ')
            req.params['page'] = next_page
            req.params['pageSize'] = 100
            req.params.merge!(additional_params || {})
          end

          raise "Error connecting to '#{response.env.url.host}'" unless response.success?

          @pages = response.headers['x-page-count'].to_i
          JSON.parse(response.body)
        end

        def load_single_data(url)
          response = Faraday.new(url: url).get do |req|
            req.headers['Authorization'] = [access_token.type, access_token.token].join(' ')
          end

          raise "Error connecting to '#{response.env.url.host}'" unless response.success?

          JSON.parse(response.body)
        end

        def refresh_access_token
          response = Faraday.new(url: URI.join("#{@client_options['scheme']}://#{@client_options['host']}", @client_options['token_endpoint'])).post do |req|
            req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
            req.body = URI.encode_www_form(@client_options.slice('username', 'password', 'client_id', 'client_secret', 'grant_type'))
          end

          raise "Error connecting to '#{response.env.url.host}'" unless response.success?

          data = JSON.parse(response.body)

          @access_token = AccessToken.new(data['access_token'], data['token_type'], (Time.zone.now + data['expires_in'].seconds))
        end
      end
    end
  end
end
