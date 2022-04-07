# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DestinationOne
      class Endpoint
        def initialize(host: nil, end_point: nil, experience: nil, licensekey: nil, template: nil, **options)
          @host = host
          @end_point = end_point
          @experience = experience
          @licensekey = licensekey
          @template = template
          @params = options.dig(:options, :params) || {}
          @max_retry = 5
          @page_size = 100
        end

        def pois(lang:)
          iterate_types(lang: lang.to_s, type: 'POI')
        end

        def hotels(lang:)
          iterate_types(lang: lang.to_s, type: 'Hotel')
        end

        def events(lang:)
          iterate_types(lang: lang.to_s, type: 'Event')
        end

        def gastros(lang:)
          iterate_types(lang: lang.to_s, type: 'Gastro')
        end

        def tours(lang:)
          iterate_types(lang: lang.to_s, type: 'Tour')
        end

        def offers(lang:)
          iterate_types(lang: lang.to_s, type: 'Package')
        end

        def articles(lang:)
          iterate_types(lang: lang.to_s, type: 'Article')
        end

        def all(lang:)
          iterate_types(lang: lang.to_s, type: 'All')
        end

        protected

        def iterate_types(lang:, type:)
          total = load_total(lang: lang, type: type)
          return [] if total.zero?
          Enumerator.new do |yielder|
            0.upto(total / @page_size).each do |page|
              load_data(lang: lang, type: type, offset: page * @page_size, limit: @page_size).each do |item|
                yielder << item
              end
            end
          end
        end

        def load_total(lang:, type:)
          limit = 1
          offset = 0
          response = request_data(lang: lang, type: type, offset: offset, limit: limit, retry_count: 0)
          response['overallcount']&.to_i || 0
        end

        def load_data(lang:, type:, offset:, limit:)
          response = request_data(lang: lang, type: type, offset: offset, limit: limit, retry_count: 0)
          response['items']
        end

        def request_data(lang:, type:, offset:, limit:, retry_count:)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point])
            req.params['experience'] = @experience
            req.params['licensekey'] = @licensekey
            req.params['template'] = @template
            req.params['type'] = type
            req.params['limit'] = limit
            req.params['offset'] = offset
            req.params['mkt'] = lang
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}?experience=#{experience}&licensekey=#{licensekey}&template=#{template}&type=#{type}&limit=#{limit}&offset=#{offset}", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count >= @max_retry
          request_data(lang: lang, type: type, retry_count: retry_count + 1)
        end
      end
    end
  end
end
