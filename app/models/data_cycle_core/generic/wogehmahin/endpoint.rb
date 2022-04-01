# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wogehmahin
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil, **_options)
          @host = host
          @end_point = end_point
          @key = key
        end

        def food_establishments(lang: :de)
          Enumerator.new do |yielder|
            load_data(lang).each do |record|
              yielder << record
            end
          end
        end

        protected

        def load_data(_lang)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point])
            req.headers['Accept'] = 'application/json'
            req.params['key'] = @key
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
