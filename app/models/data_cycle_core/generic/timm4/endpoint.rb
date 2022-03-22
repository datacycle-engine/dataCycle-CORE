# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Timm4
      class Endpoint
        def initialize(host: nil, **options)
          @host = host
          @bearer = options[:bearer]
          @limit = 50
        end

        def pois(*)
          requests(type: 'pois')
        end

        def events(*)
          requests(type: 'events')
        end

        def gastronomy(*)
          requests(type: 'gastronomy')
        end

        def tracks(*)
          requests(type: 'tracks')
        end

        def requests(type:)
          total = load_data(endpoint: type, limit: 1, offset: 0)['total']
          pages = total.fdiv(@limit).ceil
          Enumerator.new do |yielder|
            (1..pages).each do |page|
              load_data(endpoint: type, limit: @limit, offset: (page - 1) * @limit)&.dig('data')&.each do |data|
                yielder << data
              end
            end
          end
        end

        protected

        def load_data(endpoint:, limit:, offset:)
          url = [@host, endpoint].join('/')
          conn = Faraday.new(url: url) do |connection|
            connection.request(:authorization, :Bearer, @bearer)
          end

          # rate-limiting
          sleep(1)

          response = conn.get do |req|
            req.headers['Content-Type'] = 'application/json'
            req.params['offset'] = offset
            req.params['limit'] = limit
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host])}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
