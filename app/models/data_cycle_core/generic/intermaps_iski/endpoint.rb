# frozen_string_literal: true

module DataCycleCore
  module Generic
    module IntermapsIski
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host
          @end_point = end_point
          @region_id = options.dig(:region_id)
        end

        def ski_region(lang: :de)
          Enumerator.new do |yielder|
            load_ski_region(lang: lang).each do |resort|
              yielder << resort
            end
          end
        end

        protected

        def load_ski_region(*)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point)
            req.params['region_id'] = @region_id.join(',')
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / region_ids:#{@region_id}", response) unless response.success?
          JSON.parse(response.body)['items']
        end
      end
    end
  end
end
