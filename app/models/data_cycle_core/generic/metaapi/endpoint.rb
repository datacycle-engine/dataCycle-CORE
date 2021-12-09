# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Metaapi
      class Endpoint
        def initialize(host: nil, end_point: nil, api_key: nil, **options)
          @host = host
          @end_point = end_point
          @api_key = api_key
          @options = options
        end

        def accommodation_categories(*)
          Enumerator.new do |yielder|
            load_categories('GetAccommodationCategories').each do |classification|
              yielder << classification
            end
          end
        end

        def gastronomy_categories(*)
          Enumerator.new do |yielder|
            load_categories('GetGastronomyCategories').each do |classification|
              yielder << classification
            end
          end
        end

        def poi_categories(*)
          Enumerator.new do |yielder|
            load_categories('GetPoiCategories').each do |classification|
              yielder << classification
            end
          end
        end

        def tour_categories(*)
          Enumerator.new do |yielder|
            load_categories('GetTourCategories').each do |classification|
              yielder << classification
            end
          end
        end

        def event_categories(*)
          Enumerator.new do |yielder|
            load_categories('GetEventCategories').each do |classification|
              yielder << classification
            end
          end
        end

        def tours(lang: :de)
          load_main_objects('Tour', lang)
        end

        protected

        def load_main_objects(kind, lang)
          Enumerator.new do |yielder|
            paging_params = load_paging_stats("Get#{kind}ListPaging")
            (1..paging_params[:pages]).each do |page|
              load_list("Get#{kind}List", page, kind).each do |item_id|
                data = load_details("Get#{kind}Details", item_id)[kind]
                next if Array.wrap(data.dig('OBJECT_TEXT_NAME', 'string')).detect { |i| i['lang'].match(lang.to_s) }.blank?
                yielder << data
              end
            end
          end
        end

        def load_categories(method)
          url = [@host, @end_point, method + 'Proxy.php'].join('/')
          response = Faraday.new.get do |req|
            req.url url
            req.params['ApiKey'] = @api_key
          end

          data = Nokogiri::XML(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{url}", response) if data.xpath('//errorMesssage').present?
          flatten_hash_tree(data.children.first.to_hash['Category'])
        end

        def load_paging_stats(method)
          url = [@host, @end_point, method + 'Proxy.php'].join('/')
          response = Faraday.new.get do |req|
            req.url url
            req.params['ApiKey'] = @api_key
          end

          data = Nokogiri::XML(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{url}", response) if data.xpath('//errorMesssage').present?
          clean_paging_hash(data.children.first.to_hash)
        end

        def load_list(method, page, kind)
          url = [@host, @end_point, method + 'Proxy.php'].join('/')
          response = Faraday.new.get do |req|
            req.url url
            req.params['ApiKey'] = @api_key
            req.params['page'] = page
          end

          data = Nokogiri::XML(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{url}", response) if data.xpath('//errorMesssage').present?
          data.children.first.to_hash[kind].map { |i| i["#{kind}ID"] }
        end

        def load_details(method, id)
          url = [@host, @end_point, method + 'Proxy.php'].join('/')
          response = Faraday.new.get do |req|
            req.url url
            req.params['ApiKey'] = @api_key
            req.params['ObjectID'] = id
          end

          data = Nokogiri::XML(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{url}", response) if data.xpath('//errorMesssage').present?
          data.children.first.to_hash
        end

        def flatten_hash_tree(hash)
          (hash || [])&.map { |i| Array.wrap(i.except('Category')) + flatten_hash_tree(i['Category']) }&.flatten
        end

        def clean_paging_hash(hash)
          hash.map { |k, v| { k.to_sym => v['text']&.to_i } }.inject(&:merge)
        end
      end
    end
  end
end
