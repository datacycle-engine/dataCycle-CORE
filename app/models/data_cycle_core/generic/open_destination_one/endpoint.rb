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
          @max_retry = 5
        end

        def events(*)
          Enumerator.new do |yielder|
            load_data(type: 'Event', template: 'schemaorg', retry_count: 0).each do |event|
              event['keywords'] = event.dig('keywords').split(',')
              yielder << event
            end
          end
        end

        protected

        def load_data(type:, template:, retry_count: 0)
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
          if !response.success?
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
            sleep(1)
            load_data(type: type, template: template, retry_count: retry_count + 1)
          else
            JSON.parse(response.body)
          end
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_data(type: type, template: template, retry_count: retry_count + 1)
        end
      end
    end
  end
end
