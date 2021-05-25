# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleTypo3
      class Endpoint
        def initialize(host: nil, end_point: nil, token: nil, **_options)
          @host = host
          @end_point = end_point
          @token = token
        end

        def webpages(*)
          Enumerator.new do |yielder|
            load_data.each do |item|
              yielder << item
            end
          end
        end

        def mark_deleted_webpages(*)
          Enumerator.new do |yielder|
            load_data('deleted').each do |item|
              yielder << item
            end
          end
        end

        protected

        def load_data(location = nil, from = nil)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point, location].compact)
            req.params['token'] = @token
            req.params['from'] = from if from.present?
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point, location])}", response) unless response.success?
          JSON.parse(response.body)['@graph']
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_data(location, lang, retry_count + 1)
        end
      end
    end
  end
end
