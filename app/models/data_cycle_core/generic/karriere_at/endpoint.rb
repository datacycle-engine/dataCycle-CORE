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
              yielder << item
            end
          end
        end

        def load_data
          url = @host + @end_point

          connection = Faraday.new(url) do |con|
            con.use FaradayMiddleware::FollowRedirects, limit: 5
            con.adapter Faraday.default_adapter
          end

          response = connection.get do |req|
            req.url url
            req.params['fbclid'] = @fbclid
          end

          data = JSON.parse(response.body)
          # xml_data = Nokogiri::XML(response.body)

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{url} ? fbclid = #{@fbclid}", response) unless response.success?
          # xml_data.children.first.children.detect { |item| item.name == 'data' }.to_hash.dig('job')
          data['data']
        end
      end
    end
  end
end
