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
          # connection = Faraday.new(
          #   url: @host + @end_point,
          #   headers: { 'Accept' => '*/*', 'User-Agent' => 'dataCycle', 'Content-Type' => 'application/x-www-form-urlencoded' }
          # )
          # connection = Faraday.new do |conn|
          #   conn.url(@host + @end_point)
          #   conn.headers['Accept'] = '*/*'
          #   conn.headers['User-Agent'] = 'dataCycle'
          #   conn.headers['Content-Type'] = 'application/x-www-form-urlencoded'
          # end

          # Using almost standard values from the example, increased max https://www.rubydoc.info/github/lostisland/faraday/Faraday/Request/Retry
          # connection = Faraday.new do |conn|
          connection = Faraday.new(
            url: @host + @end_point,
            headers: { 'Accept' => '*/*', 'User-Agent' => 'dataCycle' }
          ) do |conn|
            conn.request :retry, max: 3, interval: 0.05,
                                 interval_randomness: 0.5, backoff_factor: 2,
                                 exceptions: [DataCycleCore::Generic::Common::Error::TooManyRequestsError, 'Timeout::Error']
            # conn.request :url_encode
            conn.response :logger
            conn.adapter Faraday.default_adapter
          end
          # connection = Faraday.new
          # body = {
          body = URI.encode_www_form(
            auth_key: @key,
            text: text,
            target_lang: target_locale.to_s.upcase,
            source_lang: source_locale.to_s.upcase
          )
          # }
          binding.pry
          response = connection.post do |req|
            # req.url(@host + @end_point)
            # req.headers['Accept'] = '*/*'
            # req.headers['User-Agent'] = 'dataCycle'
            # req.headers['Content-Type'] = 'application/x-www-form-urlencoded'
            req.body = body
          end
          binding.pry

          if response.success? && response.status == 200
            binding.pry
            raise DataCycleCore::Generic::Common::Error::TooManyRequestsError.new("#{response.status}, retrying loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response)
            # JSON.parse(response.body)
          elsif response.status == 429
            binding.pry
            raise DataCycleCore::Generic::Common::Error::TooManyRequestsError.new("#{response.status}, retrying loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response)
          else
            binding.pry
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{response.status}, error loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response)
          end

          # raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response) unless response.success?
          # binding.pry

          # data = JSON.parse(response.body)
          # raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point} / text:#{text} / source_locale:#{source_locale} / target_locale:#{target_locale}", response) unless response.status == 200
          # data
        end
      end
    end
  end
end
