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
          @headers = {
            'Accept' => '*/*',
            'User-Agent' => 'dataCycle'
          }
          @retry_options = {
            max: 3,
            interval: 1,
            interval_randomness: 0.5,
            backoff_factor: 1,
            retry_statuses: [429],
            methods: [:post]
          }
        end

        # Format translate_hash: { 'text' => 'Hallo', 'source_locale' => 'de', 'target_locale' => 'en' }
        # Format return data: nil | { 'detected_source_language' => 'DE', 'text' => 'Hello' }
        def translate(translate_hash)
          return if translate_hash.blank?
          return unless translate_hash.is_a?(::Hash) || translate_hash.is_a?(DataCycleCore::OpenStructHash)

          data = load_data(
            text: translate_hash.dig('text'),
            source_locale: translate_hash.dig('source_locale').split('-').first,
            target_locale: translate_hash.dig('target_locale').split('-').first
          )['translations']

          return if data.blank?

          data.first
        end

        def parse_translated(raw_data)
          return if raw_data.blank?
          raw_data.dig('text')
        end

        def load_data(text: nil, source_locale: nil, target_locale: nil)
          connection = Faraday.new(
            url: @host + @end_point,
            headers: @headers
          ) do |conn|
            conn.request :retry, @retry_options
            conn.request :url_encoded
            conn.response :logger
            conn.adapter Faraday.default_adapter
          end

          response = connection.post do |req|
            req.body = {
              auth_key: @key,
              text: Nokogiri::HTML5.fragment(text).to_xml, # transform HTML Entities to valid XML
              target_lang: target_locale.to_s.upcase,
              source_lang: source_locale.to_s.upcase,
              tag_handling: 'xml'
            }
          end

          if response.success?
            JSON.parse(response.body)
          elsif response.status == 456
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{response.status}, Quota exceeded for #{@host + @end_point} / key:#{@key}", response)
          else
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{response.status}, error loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response)
          end
        end
      end
    end
  end
end
