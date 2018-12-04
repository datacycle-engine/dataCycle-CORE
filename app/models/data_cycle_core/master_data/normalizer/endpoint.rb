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

          # normalized_hash = load_data(reduce_data(data_hash))
          # normalized_hash['entry']['fields'] = merge_ids(normalized_hash.dig('entry', 'fields'), data_hash)
          # normalized_hash
          load_data(reduce_data(data_hash))
        end

        # def merge_ids(obtained_hash, data_hash)
        #   items = (obtained_hash.map { |item| item.dig('type') } + data_hash.map { |item| item.dig('type') }).uniq
        #   items.map { |item|
        #     ({}&.merge(data_hash.find(ifnone = {}) { |entry| entry&.dig('type') == item }))
        #       &.merge(obtained_hash.find(ifnone = {}) { |entry| entry&.dig('type') == item })
        #   }.reject { |item| item == {} }
        # end

        def reduce_data(data_list)
          data_list.map { |item| item.except('id') }
        end

        def load_data(data_list)
          response = Faraday.new.post do |req|
            req.url(@host + @end_point)
            req.headers['Accept'] = 'application/json'
            req.headers['Content-Type'] = 'application/json'
            req.body = {
              id: '123xyz',
              comment: 'API Test',
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
