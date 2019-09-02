# frozen_string_literal: true

module DataCycleCore
  module Generic
    module HrsDestinationData
      class Endpoint
        def initialize(host: nil, end_point: nil, api_key: nil, **_options)
          @host = host
          @end_point = end_point
          @api_key = api_key
          @per_page = 100
        end

        def events(lang: :de)
          Enumerator.new do |yielder|
            items = load_data(0, 1, lang).dig('count', 'max')
            max_pages = (items.to_f / @per_page).ceil
            (0..max_pages).each do |page|
              load_data(page, @per_page, lang).dig('entries').each do |event|
                yielder << event
              end
            end
          end
        end

        protected

        def load_data(page, max, _lang)
          connection = Faraday.new(@host + @end_point) do |con|
            con.use FaradayMiddleware::FollowRedirects, limit: 5
            con.adapter Faraday.default_adapter
          end
          response = connection.get do |req|
            req.url File.join([@host, @end_point, 'event'])
            req.headers['Accept'] = 'application/json'
            req.params['apiKey'] = @api_key
            req.params['from'] = '2019-01-01'
            req.params['to'] = '2019-12-31'
            req.params['region'] = 1
            req.params['max'] = max
            req.params['page'] = page
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
