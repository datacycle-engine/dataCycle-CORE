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

        def normalize(id, data_list, comment = 'data_cycle')
          return if data_list.blank?
          load_data(id.presence || SecureRandom.uuid, comment, data_list)
        end

        def load_data(id, comment, data_list)
          response = Faraday.new.post do |req|
            req.url(@host + @end_point)
            req.headers['Accept'] = 'application/json'
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              id:,
              comment:,
              fields: data_list
            }.to_json
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point}", response) unless response.success?
          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point}", response) unless data['status'] == 'OK'
          data
        end
      end
    end
  end
end
