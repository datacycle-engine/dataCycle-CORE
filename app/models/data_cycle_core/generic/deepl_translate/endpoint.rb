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

        # TODO: error handling (especially resend), translate all button
        def translate(translate_hash)
          return if translate_hash.blank?
          return unless translate_hash.is_a?(::Hash) || translate_hash.is_a?(DataCycleCore::OpenStructHash)

          data = load_data(text: translate_hash.dig('text'), source_locale: translate_hash.dig('source_locale'), target_locale: translate_hash.dig('target_locale'))['translations']
          return if data.blank?

          data.first
        end

        def parse_translated(raw_data)
          return if raw_data.blank?
          raw_data.dig('text')
        end

        def load_data(text: nil, source_locale: nil, target_locale: nil)
          response = Faraday.new.post do |req|
            req.url(@host + @end_point)
            req.headers['Accept'] = '*/*'
            req.headers['User-Agent'] = 'dataCycle'
            req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
            req.body = {
              auth_key: @key,
              text: text,
              target_lang: target_locale.to_s.upcase,
              source_lang: source_locale.to_s.upcase
            }
          end
          # TODO: https://www.deepl.com/docs-api/accessing-the-api/error-handling
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response) unless response.success?

          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response) unless response.status == 200
          data
        end
      end
    end
  end
end
