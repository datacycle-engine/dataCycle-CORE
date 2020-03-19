# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DeeplTranslate
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil, **options)
          @host = host
          @end_point = end_point
          @key = key
          @options = options
        end

        def translate(text, locale = I18n.locale)
          return if text.blank?
          return unless text.is_a?(::Hash) || text.is_a?(DataCycleCore::OpenStructHash)

          # address_string = [address.dig('street_address'), [address.dig('postal_code'), address.dig('address_locality')].join(' '), address.dig('address_country')].join(', ')
          data = load_data(text: text, locale: locale)['translations']
          return if data.blank?

          parse_translated(data.first)
        end

        def parse_translated(raw_data)
          return if raw_data.blank?
          raw_data.dig('text')
        end

        def load_data(text: nil, locale: :de)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point)
            req.headers['Accept'] = '*/*'
            req.headers['User-Agent'] = 'dataCycle'
            # req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
            req.body = {
              auth_key: @key,
              text: text,
              target_lang: locale.to_s.upcase,
              source_lang: ''
            }
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + 'geocode/json'} / latlng:#{latlng} / address:#{address}", response) unless response.success?
          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point + 'geocode/json'} / latlng:#{latlng} / address:#{address}", response) unless data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS'
          data
        end
      end
    end
  end
end
