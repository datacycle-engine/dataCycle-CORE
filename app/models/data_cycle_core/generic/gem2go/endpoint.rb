# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gem2go
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host
          @end_point = end_point
          @hash = options[:hash]
          @id = options[:id]
          @area = options[:area]
          @max_retry = 5
          @params = options.dig(:options, :params) || {}
        end

        def events(lang: :de)
          # external_keys = @params[:external_keys]
          # changed_from = @params[:changed_from]&.to_date&.to_s(:db) || '2000-01-01'
          Enumerator.new do |yielder|
            Array.wrap(@area).each do |area|
              load_events(area: area, lang: lang)&.each do |event_data|
                yielder << event_data
              end
            end
          end
        end

        protected

        def load_events(area:, lang:, retry_count: 0)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point])
            req.params['hash'] = @hash
            req.params['id'] = @id
            req.params['area'] = area
          end

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}/#{@end_point}?id=#{@id}&area=#{area}&hash=#{@hash}", response) unless response.success?
          data = Nokogiri::XML(response.body)

          eventlist = data.xpath('//events/eventlist')
          return [] if eventlist.blank?
          Array.wrap(eventlist.first.to_hash['event'])
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_events(area: area, lang: lang, retry_count: retry_count + 1)
        end
      end
    end
  end
end
