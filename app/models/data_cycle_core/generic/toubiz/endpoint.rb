# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Toubiz
      class Endpoint
        def initialize(host: nil, end_point: nil, bearer: nil, **options)
          @host = host
          @end_point = end_point
          @bearer = bearer
          @params = options.dig(:options, :params) || {}
          @max_retry = 5
          @page_size = 20
        end

        def faraday
          Faraday.new(request: { timeout: 1200 }) do |f|
            f.request :url_encoded
            f.request :retry, max: 7, interval: 60, backoff_factor: 2, exceptions: [StandardError]

            f.request(:authorization, :Bearer, @bearer)

            f.response :follow_redirects
          end
        end

        def categories(lang:)
          Enumerator.new do |yielder|
            request_categories(lang: lang, type: 'category', retry_count: 0).each do |item|
              yielder << item
            end
          end
        end

        def pois(lang:)
          includes = ['fieldValues', 'fieldBlueprints', 'externalIds', 'media', 'files', 'emails', 'contactInformation', 'phoneNumbers', 'tags', 'seo']
          iterate_types(lang: lang.to_s, type: 'article', import_type: ['point'], includes: includes)
        end

        def tours(lang:)
          includes = ['fieldValues', 'fieldBlueprints', 'externalIds', 'media', 'files', 'emails', 'contactInformation', 'phoneNumbers', 'tags', 'seo', 'tourStageRelations']
          iterate_types(lang: lang.to_s, type: 'article', import_type: ['tour'], includes: includes)
        end

        def events(lang:)
          includes = ['files', 'media', 'tags', 'dates', 'contactInformation', 'fieldBlueprints', 'printInformation', 'fieldValues', 'host', 'location', 'category', 'externalIds']
          iterate_types(lang: lang.to_s, type: 'event', import_type: ['local', 'regional', 'multiregional'], includes: includes)
        end

        protected

        def iterate_types(lang:, type:, import_type:, includes:)
          keys = load_index(lang: lang, type: type)
          return [] if keys.blank?
          Enumerator.new do |yielder|
            keys.each do |id|
              data = request_data_details(lang: lang, type: type, id: id, includes: includes, retry_count: 0)
              next unless data['type'].in?(import_type)
              yielder << data
            end
          end
        end

        def load_total(lang:, type:)
          page = 1
          page_size = 1
          response = request_data(lang: lang, type: type, includes: [], page: page, page_size: page_size, retry_count: 0)
          response.dig('_attributes', 'pagination', 'total')&.to_i || 0
        end

        def load_index(lang:, type:)
          response = request_data_min(lang: lang, type: type, retry_count: 0)
          response['payload'].keys
        end

        def load_data(lang:, type:, includes:, page:, page_size:)
          response = request_data(lang: lang, type: type, includes: includes, page: page, page_size: page_size, retry_count: 0)
          response['payload']
        end

        def request_data_details(lang:, type:, id:, includes:, retry_count:)
          url = [@host, @end_point, type, id].join('/')
          response = faraday.get(url) do |req|
            req.headers['Content-Type'] = 'application/json'
            req.params['language'] = lang.to_s
            req.params['include'] = includes
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}/#{type}/#{id}?...", response) unless response.success?
          JSON.parse(response.body)['payload']
        rescue StandardError
          raise if retry_count >= @max_retry
          request_data_details(lang: lang, type: type, id: id, includes: includes, retry_count: retry_count + 1)
        end

        def request_data(lang:, type:, includes:, page:, page_size:, retry_count:)
          url = [@host, @end_point, type].join('/')
          response = faraday.get(url) do |req|
            req.headers['Content-Type'] = 'application/json'
            req.params['pagination'] = { 'page' => page, 'pageSize' => page_size }
            req.params['language'] = lang.to_s
            req.params['include'] = includes
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}/#{type}?...", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count >= @max_retry
          request_data(lang: lang, type: type, includes: includes, page: page, page_size: page_size, retry_count: retry_count + 1)
        end

        def request_data_min(lang:, type:, retry_count:)
          url = [@host, @end_point, type].join('/')
          response = faraday.get(url) do |req|
            req.headers['Content-Type'] = 'application/json'
            req.params['language'] = lang.to_s
            req.params['minimal'] = 1
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}/#{type}?minimal=1&language=#{lang}...", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count >= @max_retry
          request_data_min(lang: lang, type: type, retry_count: retry_count + 1)
        end

        def request_categories(lang:, type:, retry_count:)
          url = [@host, @end_point, type].join('/')
          response = faraday.get(url) do |req|
            req.headers['Content-Type'] = 'application/json'
            req.params['language'] = lang.to_s
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}/#{type}?language=#{lang}...", response) unless response.success?
          JSON.parse(response.body)['payload']
        rescue StandardError
          raise if retry_count >= @max_retry
          request_categories(lang: lang, type: type, retry_count: retry_count + 1)
        end
      end
    end
  end
end
