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

        protected

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

        def flatten_hash_tree(hash)
          (hash || [])&.map { |i| Array.wrap(i.except('Category')) + flatten_hash_tree(i['Category']) }&.flatten
        end
      end
    end
  end
end
