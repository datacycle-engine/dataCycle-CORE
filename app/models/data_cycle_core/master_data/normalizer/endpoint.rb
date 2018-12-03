# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Normalizer
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host || 'https://datacycle-di.econob.com'
          @end_point = end_point || '/normalizeEntryDetails'
          @options = options
        end

        def normalize(data_hash)
          return if data_hash.blank?
          load_data(data_hash)
        end

        def load_data(_data_hash)
          response = Faraday.new.post do |req|
            req.url(@host + @end_point)
            req.headers['Accept'] = 'application/json'
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              id: '123xyz',
              comment: 'API Test',
              fields: [
                { id: 'SEX', type: 'SEX', content: 'male' },
                { id: 'forename', type: 'FORENAME', content: 'Sabine' },
                { id: 'surname', type: 'SURNAME', content: 'Hassler' },
                { id: 'Strasse', type: 'STREET', content: 'Lakeside b01' },
                { id: 'Stadt', type: 'CITY', content: 'Klagenfurt' },
                { id: 'COUNTRY', type: 'COUNTRY', content: 'Austria' }
              ]
            }.to_json
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point}", response) unless response.success?
          data = JSON.parse(response.body)
          ap data
          byebug
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point}", response) unless data['status'] == 'OK'
          data
        end
      end
    end
  end
end
