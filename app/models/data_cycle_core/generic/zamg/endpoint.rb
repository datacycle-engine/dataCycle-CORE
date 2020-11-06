# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Zamg
      class Endpoint
        def initialize(host:, end_point:, **_options)
          @host = host
          @end_point = end_point
        end

        def weather(*)
          Enumerator.new do |yielder|
            full_data = load_data
            meta = full_data.dig('01_meta')
            full_data.except('01_meta').each do |key, data|
              yielder << data.merge({ 'name' => key, 'metadata' => meta })
            end
          end
        end

        def weather_symbols(*)
          Enumerator.new do |yielder|
            load_data.dig('01_meta', 'symbolcodes').each do |key, value|
              yielder << { 'code' => key.split('_').last, 'value' => "<p>#{value}</p>" }
            end
          end
        end

        private

        def load_data
          conn = Faraday.new(url: [@host, @end_point].join('/'))
          response = conn.get

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{[@host, @end_point].join('/')}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
