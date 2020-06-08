# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Hrs
      class Endpoint
        def initialize(host: nil, end_point: nil, interface_id: nil, region_name: nil, **_options)
          @host = host
          @end_point = end_point
          @interface_id = interface_id
          @region_name = region_name
          @max_retry = 5
        end

        def rooms(lang: :de)
          Enumerator.new do |yielder|
            load_data('v1/rooms', lang).dig('room').each do |room|
              yielder << room
            end
          end
        end

        def category(lang: :de)
          Enumerator.new do |yielder|
            load_file('o_category.json', lang).each do |key, value|
              yielder << { 'id' => key, 'name' => value }
            end
          end
        end

        def ausstattung(lang: :de)
          Enumerator.new do |yielder|
            load_file('o_ausstattung.json', lang).each do |key, value|
              yielder << { 'id' => key, 'name' => value }
            end
          end
        end

        def leisure(lang: :de)
          Enumerator.new do |yielder|
            load_file('o_leisure.json', lang).each do |key, value|
              yielder << { 'id' => key, 'name' => value }
            end
          end
        end

        def stars(lang: :de)
          Enumerator.new do |yielder|
            load_file('o_sterne.json', lang).each do |key, value|
              yielder << { 'id' => key, 'name' => value }
            end
          end
        end

        protected

        def load_data(location, lang, retry_count = 0)
          response = Faraday.new.post do |req|
            req.url File.join([@host, @end_point, location])
            req.headers['Content-Type'] = 'application/json'
            req.body = { 'para' => { 'interface_id' => @interface_id, 'region_name' => @region_name } }.to_json
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{File.join([@host, @end_point])}", response) unless response.success?
          Nokogiri::XML(response.body).xpath('//rooms/content').first.to_hash
        rescue StandardError
          raise if retry_count > @max_retry
          sleep(1)
          load_data(location, lang, retry_count + 1)
        end

        def load_file(file_name, _lang)
          full_path = [
            'vendor', 'gems', 'data-cycle-core', 'app', 'models',
            'data_cycle_core', 'generic', 'hrs', 'json'
          ] + [file_name]
          path = Rails.root.join(*full_path)
          JSON.parse(File.read(path))
        end
      end
    end
  end
end
