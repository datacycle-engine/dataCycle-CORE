# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Hrs
      class Endpoint
        def initialize(host: nil, end_point: nil, interface_id: nil, region_name: nil, **_options)
          @host = host
          @end_point = end_point
          @interface_id = interface_id
          @region_name = region_name
        end

        def rooms(lang: :de)
          Enumerator.new do |yielder|
            load_data('v1/rooms', lang).dig('room').each do |room|
              yielder << room
            end
          end
        end

        protected

        def load_data(location, _lang)
          response = Faraday.new.post do |req|
            req.url File.join([@host, @end_point, location])
            req.headers['Content-Type'] = 'application/json'
            req.body = { 'para' => { 'interface_id' => @interface_id, 'region_name' => @region_name } }.to_json
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          Nokogiri::XML(response.body).xpath('//rooms/content').first.to_hash
        end
      end
    end
  end
end
