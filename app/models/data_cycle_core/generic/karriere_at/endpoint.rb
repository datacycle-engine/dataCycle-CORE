# frozen_string_literal: true

module DataCycleCore
  module Generic
    module KarriereAt
      class Endpoint
        def initialize(host:, end_point:, fbclid:, **options)
          @host = host
          @end_point = end_point
          @fbclid = fbclid
          @options = options
        end

        def jobs(*)
          Enumerator.new do |yielder|
            load_data.each do |item|
              yielder << item.dig('children')
            end
          end
        end

        def load_data
          url = @host + @end_point

          response = Faraday.new.get do |req|
            req.url url
            req.params['fbclid'] = @fbclid
          end

          xml_data = Nokogiri::XML(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@url + @end_point} ? fbclid = #{@fbclid}", response) unless response.success?
          xml_data.children.first.children.detect { |item| item.name == 'data' }.to_hash.dig('job')
        end
      end
    end
  end
end
