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

        # TODO: get target and source_lang, error handling (especially resend), translate all button
        def translate(text, locale = I18n.locale)
          return if text.blank?
          return unless text.is_a?(::Hash) || text.is_a?(DataCycleCore::OpenStructHash)
          # binding.pry
          # address_string = [address.dig('street_address'), [address.dig('postal_code'), address.dig('address_locality')].join(' '), address.dig('address_country')].join(', ')
          data = load_data(text: text, locale: locale)['translations']
          return if data.blank?
          # binding.pry
          # parse_translated(data.first)
          data.first
        end

        def parse_translated(raw_data)
          return if raw_data.blank?
          raw_data.dig('text')
        end

        def load_data(text: nil, locale: :de)
          response = Faraday.new.post do |req|
            req.url(@host + @end_point)
            req.headers['Accept'] = '*/*'
            req.headers['User-Agent'] = 'dataCycle'
            # req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
            req.body = {
              auth_key: @key,
              text: text['text'],
              target_lang: locale.to_s.upcase,
              source_lang: ''
            }
          end
          # TODO: https://www.deepl.com/docs-api/accessing-the-api/error-handling
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / text:#{text} / locale:#{locale}", response) unless response.success?
          # binding.pry
          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point} / text:#{text} / locale:#{locale}", response) unless response.status == 200
          data
        end
      end
    end
  end
end
