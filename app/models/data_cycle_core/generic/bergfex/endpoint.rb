# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      class Endpoint
        def initialize(host: nil, end_point: nil, partner: nil, **options)
          @host = host
          @end_point = end_point
          @partner = partner
        end

        def lakes(lang: :de)
          Enumerator.new do |yielder|
            load_data.each do |lake|
              yielder << lake
            end
          end
        end

        protected

        def load_data
          response = Faraday.new.get do |req|
            req.url(@host + @end_point)
            req.params['partner'] = @partner
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / partner:#{@partner}", response) unless response.success?
          Nokogiri::XML(response.body).xpath('//lakes').first.to_hash['lake']
        end
      end
    end
  end
end
