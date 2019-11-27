# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      class Endpoint
        def initialize(host: nil, end_point: nil, key: nil, **_options)
          @host = host
          @end_point = end_point
          @key = key
          @per = 100
        end

        def spots(lang: :de)
          first_page = load_collection('spots', 0, lang)
          total_items = first_page['meta']['total'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_collection('spots', page - 1, lang)['data'].each do |image_record|
                yielder << image_record
              end
            end
          end
        end

        def contents(lang: :de)
          first_page = load_collection('contents', 0, lang)
          total_items = first_page['meta']['total'].to_i
          max_pages = total_items.fdiv(@per).ceil
          Enumerator.new do |yielder|
            (1..max_pages).each do |page|
              load_collection('contents', page - 1, lang)['data'].each do |image_record|
                raw_data = load_item(image_record['id'], 'contents', lang)
                yielder << raw_data['data'].merge('included' => raw_data['included'])
              end
            end
          end
        end

        protected

        def load_collection(type = 'spots', page = 0, lang = :de)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point, type])

            req.headers['Accept'] = 'application/json'
            req.headers['Apikey'] = @key
            req.params['lang'] = lang.to_s
            req.params['page[size]'] = @per
            req.params['page[cursor]'] = page
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        end

        def load_item(id, type, lang = :de)
          response = Faraday.new.get do |req|
            req.url File.join([@host, @end_point, type, id])

            req.headers['Accept'] = 'application/json'
            req.headers['Apikey'] = @key
            req.params['lang'] = lang.to_s
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          JSON.parse(response.body)
        end
      end
    end
  end
end
