# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OpenDestinationOne
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host
          @end_point = end_point
          @experience = options[:experience]
          @licensekey = options[:licensekey]
        end

        def events(*)
          Enumerator.new do |yielder|
            load_data(type: 'Event', template: 'schemaorg').each do |event|
              event['keywords'] = event.dig('keywords').split(',')
              yielder << event
            end
          end
        end

        protected

        def load_data(type:, template:)
          url = [@host, @end_point].join('/')
          connection = Faraday.new(url) do |con|
            con.use FaradayMiddleware::FollowRedirects, limit: 5
            con.adapter Faraday.default_adapter
          end

          response = connection.get do |req|
            req.headers['Accept'] = 'application/json'
            req.params['experience'] = @experience
            req.params['licensekey'] = @licensekey
            req.params['type'] = type
            req.params['template'] = template
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
