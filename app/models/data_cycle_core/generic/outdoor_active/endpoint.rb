# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      class Endpoint
        def initialize(host: nil, end_point: nil, project: nil, key: nil, **_options)
          @host = host
          @end_point = end_point
          @project = project
          @key = key
          @max_retry = 10
        end

        def faraday
          Faraday.new(request: { timeout: 1200 }) do |f|
            f.request :url_encoded
            f.request :retry, max: @max_retry, interval: 3, backoff_factor: 2, exceptions: [StandardError]

            f.response :follow_redirects
          end
        end

        def tour_categories(lang: :de)
          Enumerator.new do |yielder|
            process_category = lambda do |category_data|
              yielder << category_data.except('category')

              (category_data['category'] || []).each do |child_category_data|
                process_category.call(child_category_data.merge({ 'parentId' => category_data['id'] }))
              end
            end

            load_data(['category', 'tree', 'tour'], lang)['category'].each do |category_data|
              process_category.call(category_data)
            end
          end
        end

        def place_categories(lang: :de)
          Enumerator.new do |yielder|
            process_category = lambda do |category_data|
              yielder << category_data.except('category')

              (category_data['category'] || []).each do |child_category_data|
                process_category.call(child_category_data.merge({ 'parentId' => category_data['id'] }))
              end
            end

            load_data(['category', 'tree', 'poi'], lang)['category'].each do |category_data|
              process_category.call(category_data)
            end
          end
        end

        def categories(lang: :de)
          Enumerator.new do |yielder|
            process_category = lambda do |category_data|
              yielder << category_data.except('category')

              (category_data['category'] || []).each do |child_category_data|
                process_category.call(child_category_data.merge({ 'parentId' => category_data['id'] }))
              end
            end

            load_data(['category', 'tree'], lang)['category'].each do |category_data|
              process_category.call(category_data)
            end
          end
        end

        def regions(lang: :de)
          Enumerator.new do |yielder|
            process_region = lambda do |region_data|
              yielder << region_data.except('region')

              (region_data['region'] || []).each do |child_region_data|
                process_region.call(child_region_data.merge({ 'parentId' => region_data['id'] }))
              end
            end

            load_data(['region', 'tree'], lang)['region'].each do |region_data|
              process_region.call(region_data)
            end
          end
        end

        def places(lang: :de)
          Enumerator.new do |yielder|
            pois = load_data(['pois'], lang)
            raise "DataCycle::Generic::OutdoorActive (not data received from Endpoint) -> error loading data from #{File.join([@host, @end_point, @project, 'pois'])} / lang:#{lang}" if pois['data'].blank?
            pois['data'].each do |poi_id_container|
              raw_data_item = load_data(['oois', poi_id_container['id']], lang)
              next if raw_data_item.blank?
              raw_data = raw_data_item['poi'][0]
              sleep(0.1)
              yielder << raw_data if raw_data.dig('meta', 'translation').include?(lang.to_s)
            end
          end
        end

        def tours(lang: :de)
          Enumerator.new do |yielder|
            tours = load_data(['tours'], lang)
            raise "DataCycle::Generic::OutdoorActive (not data received from Endpoint) -> error loading data from #{File.join([@host, @end_point, @project, 'tours'])} / lang:#{lang}" if tours['data'].blank?
            tours['data'].each do |tour_id_container|
              raw_data_item = load_data(['oois', tour_id_container['id']], lang)
              next if raw_data_item.blank?
              raw_data = raw_data_item['tour'][0]
              sleep(0.1)
              yielder << raw_data if raw_data.dig('meta', 'translation').include?(lang.to_s)
            end
          end
        end

        protected

        def load_data(url_path, lang = :de)
          response = faraday.get do |req|
            req.url File.join([@host, @end_point, @project] + url_path)

            req.headers['Accept'] = 'application/json'

            req.params['key'] = @key
            req.params['lang'] = lang
            req.params['fallback'] = false
            req.params['display'] = 'external'
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("DataCycle::Generic::OutdoorActive -> error loading data from #{File.join([@host, @end_point, @project] + url_path)} / lang:#{lang}", response) unless response.success?

          JSON.parse(response.body)
        end
      end
    end
  end
end
