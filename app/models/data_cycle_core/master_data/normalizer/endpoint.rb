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

        def normalize(id, data_list)
          return if data_list.blank?
          load_data(id || SecureRandom.uuid, data_list)
        end

        def load_data(id, data_list)
          response = Faraday.new.post do |req|
            req.url(@host + @end_point)
            req.headers['Accept'] = 'application/json'
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              id: id,
              fields: data_list
            }.to_json
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point}", response) unless response.success?
          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point}", response) unless data['status'] == 'OK'
          data
        end

        # def test_data
        #   {
        #     'id' => '123',
        #     'comment' => 'Any text comment, if required or helpful',
        #     'fields' => [
        #       { 'id' => 'SEX', 'type' => 'SEX', 'content' => 'male' },
        #       { 'id' => 'DEGREE', 'type' => 'DEGREE', 'content' => 'Dipl Ing' },
        #       { 'id' => 'FORENAME', 'type' => 'FORENAME', 'content' => 'Karin' },
        #       { 'id' => 'SURNAME', 'type' => 'SURNAME', 'content' => 'Smith' },
        #       { 'id' => 'COMPANY', 'type' => 'COMPANY', 'content' => 'Hofer AG' },
        #       { 'id' => 'STREET', 'type' => 'STREET', 'content' => 'Landstr.' },
        #       { 'id' => 'STREETNR', 'type' => 'STREETNR', 'content' => '12f' },
        #       { 'id' => 'CITY', 'type' => 'CITY', 'content' => 'Klagenfurt' },
        #       { 'id' => 'ZIP', 'type' => 'ZIP', 'content' => '9020' },
        #       { 'id' => 'COUNTRY', 'type' => 'COUNTRY', 'content' => 'Aut' },
        #       { 'id' => 'BIRTHDATE', 'type' => 'BIRTHDATE', 'content' => '13/06/2018' },
        #       { 'id' => 'EMAIL', 'type' => 'EMAIL', 'content' => 'me_AT_internet.com' },
        #       { 'id' => 'EVENTNAME', 'type' => 'EVENTNAME', 'content' => 'Wörthersee Businesslauf' },
        #       { 'id' => 'DATETIME', 'type' => 'DATETIME', 'content' => 'heute' },
        #       { 'id' => 'DATETIME2', 'type' => 'DATETIME', 'content' => '30.10.2019, 15=>48' },
        #       { 'id' => 'PLACE', 'type' => 'PLACE', 'content' => 'Konzerthaus Großer Saal' },
        #       { 'id' => 'LATITUDE', 'type' => 'LATITUDE', 'content' => '48.210033' },
        #       { 'id' => 'LONGITUDE', 'type' => 'LONGITUDE', 'content' => '16.363449' }
        #     ]
        #   }
        # end
      end
    end
  end
end
