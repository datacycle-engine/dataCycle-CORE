# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      class Endpoint
        def initialize(host: nil, url_part: nil, end_point: nil, apikey: nil, **options)
          @host = host
          @url_part = url_part
          @end_point = end_point
          @apikey = apikey
          @read_type = options[:read_type] if options[:read_type].present?
          @bergerlebnis = options.dig(:endpoint_bergerlebnis)
          @event = options.dig(:endpoint_event)
          @eventreihe = options.dig(:endpoint_eventreihe)
          @max_retry = 5
        end

        def infrastructures(lang: :de)
          first_page = load_data(1, lang, 0)
          max_pages = first_page['totalPages'].to_i
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_data(page - 1, lang, 0)['items'].each do |infrastructure_record|
                yielder << infrastructure_record
              end
            end
          end
        end

        def bergerlebnis(lang: :de)
          page_event(@bergerlebnis, 'bergerlebnis', lang.to_s)
        end

        def event(lang: :de)
          page_event(@event, 'event', lang.to_s)
        end

        def eventreihe(lang: :de)
          page_event(@eventreihe, 'eventreihe', lang.to_s)
        end

        protected

        def load_data(page = 1, lang = :de, retry_count = 0)
          sleep 2 # rate limit requests

          response = Faraday.new.get do |req|
            req.url File.join([@host, @url_part, lang.to_s, @end_point])
            req.params['apikey'] = @apikey
            req.params['page'] = page
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_data(page, lang, retry_count + 1)
        end

        def page_event(end_point, type, lang)
          bergerlebnis = []
          bergerlebnis, bergerlebnis_data = load_bergerlebnis_ids(lang) if type == 'event'
          first_page = load_events(end_point, 1)
          max_pages = first_page['pages'].to_i
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_events(end_point, page)['items'].each do |event_data|
                if event_data.dig('id').in?(bergerlebnis) # enrich data with bergerlebnis data
                  event_data['isBergerlebnis'] = true
                  bergerlebnis_attributes = bergerlebnis_data.detect { |i| i.dig('external_id').to_s == event_data.dig('id').to_s }
                  event_data['localizedData'] = bergerlebnis_attributes['localizedData']
                  event_data['difficulty'] = bergerlebnis_attributes['difficulty']
                else
                  event_data['localizedData'] = event_data['localizedData'][lang]
                end
                yielder << event_data.merge('import_type' => type)
              end
            end
          end
        end

        def load_events(end_point, page = 1, retry_count = 0)
          response = Faraday.new.get do |req|
            req.url File.join([@host, end_point])
            req.params['page'] = page
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_events(end_point, page, retry_count + 1)
        end

        def load_bergerlebnis_ids(lang)
          raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?
          bergerlebnis_ids = nil
          bergerlebnis_data = {}
          DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            all_data = mongo.where({ 'external_id' => { '$exists' => true } }).to_a
            bergerlebnis_ids = all_data.map { |i| i['external_id'].to_i }
            bergerlebnis_data = all_data.map { |i| { 'external_id' => i['external_id'], 'localizedData' => i.dump.dig(lang.to_s, 'localizedData'), 'difficulty' => i.dump.dig(lang.to_s, 'difficulty') } }
          end
          return bergerlebnis_ids, bergerlebnis_data
        end
      end
    end
  end
end
