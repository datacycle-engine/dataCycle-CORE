# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelResort
      class Endpoint
        def initialize(host: nil, end_point: nil, id: nil, **_options)
          @host = host
          @end_point = end_point
          @id = id
        end

        def infrastructure(_lang: :de)
          Enumerator.new do |yielder|
            load_data['INFRA'].each do |infrastructure|
              yielder << infrastructure
            end
          end
        end

        protected

        def load_data
          connection = Faraday.new(@host + @end_point) do |con|
            con.use FaradayMiddleware::FollowRedirects, limit: 5
            con.adapter Faraday.default_adapter
          end
          response = connection.get do |req|
            req.params['id'] = @id
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / id:#{@id}", response) unless response.success?
          Nokogiri::XML(response.body).xpath('//RESORT/INFRASTRUKTUR').first.to_hash
        end
      end
    end
  end
end
