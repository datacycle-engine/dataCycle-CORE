# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gem2go
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host
          @end_point = end_point
          @hash = options[:hash]
          @max_retry = 5
          @params = options.dig(:options, :params) || {}
        end

        def events(lang: :de)
          # external_keys = @params[:external_keys]
          # changed_from = @params[:changed_from]&.to_date&.to_s(:db) || '2000-01-01'
          Enumerator.new do |yielder|
            load_events(lang: lang)&.each do |event_data|
              yielder << event_data
            end
          end
        end

        protected

        def load_events(lang:, retry_count: 0)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point])
            req.params['hash'] = @hash
            req.params['id'] = '107'
            req.params['area'] = '80240'
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}?(Lang=#{lang}&)hash=#{@hash}", response) unless response.success?
          data = Nokogiri::XML(response.body)
          data.xpath('//events/eventlist').first.to_hash['event']
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_events(lang: lang, retry_count: retry_count + 1)
        end
      end
    end
  end
end
