# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wikidata
      class Endpoint
        def initialize(host: nil, **options)
          @host = host
          @options = options
          @read_type = options[:read_type] if options[:read_type].present?
          @top_classifications = options.dig(:options, :top_classifications) || ['Q960648']
          @countries = options.dig(:options, :countries) || ['Q40']
          @per = 50
        end

        def pois(*)
          Enumerator.new do |yielder|
            @countries.each do |country_code|
              load_data(country_code).each do |poi_data|
                yielder << poi_data
              end
            end
          end
        end

        def images(*)
          Enumerator.new do |yielder|
            load_image_names.each_slice(@per) do |image_names|
              load_image_data(image_names).each do |image_data|
                image_data['categories'] = image_data.dig('imageinfo', 0, 'extmetadata', 'Categories', 'value')&.split('|')
                yielder << image_data
              end
            end
          end
        end

        def classifications(*)
          Enumerator.new do |yielder|
            @top_classifications.each do |top_class|
              load_classification_data(top_class).each do |class_data|
                class_data['external_key'] = class_data.dig('class', 'value').split('/').last
                class_data['parent_key'] = class_data.dig('parent', 'value').split('/').last
                class_data['parent_key'] = nil if class_data['external_key'] == top_class
                yielder << class_data
              end
            end
          end
        end

        protected

        def load_image_names
          raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?
          DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            mongo
              .where({ 'dump.de.image.value' => { '$exists' => true } })
              .to_a
              .map { |data| data.dump.dig('de', 'image', 'value') }
              .map { |data| "File:#{URI.decode_www_form_component(data.split('/').last)}" }
          end
        end

        def load_data(country_code)
          response = Faraday.new.post do |req|
            req.url(@host)
            req.headers['Accept'] = 'application/sparql-results+json'
            req.headers['content-type'] = 'application/sparql-query'
            req.headers['user-agent'] = 'Ruby 2.6.4'
            req.body = <<-EOS
              SELECT DISTINCT ?item ?itemLabel ?itemDescription ?class ?classLabel ?image ?location ?url ?email ?fax ?phone ?street ?old_street ?postal_code ?country ?countryLabel ?category
              WHERE {
                ?item wdt:P17 wd:#{country_code}.
                ?class wdt:P279* wd:Q960648.
                ?item wdt:P31 ?class.
                OPTIONAL { ?item wdt:P18 ?image. }
                OPTIONAL { ?item wdt:P625 ?location. }
                OPTIONAL { ?item wdt:P856 ?url. }
                OPTIONAL { ?item wdt:P968 ?email. }
                OPTIONAL { ?item wdt:P2900 ?fax. }
                OPTIONAL { ?item wdt:P1329 ?phone. }
                OPTIONAL { ?item wdt:P6375 ?street. }
                OPTIONAL { ?item wdt:P969 ?old_street. }
                OPTIONAL { ?item wdt:P281 ?postal_code. }
                OPTIONAL { ?item wdt:P17 ?country. }
                OPTIONAL { ?item wdt:P373 ?category. }
                SERVICE wikibase:label { bd:serviceParam wikibase:language "de". }
              }
            EOS
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host} / for #{country_code}", response) unless response.success?
          JSON.parse(response.body).dig('results', 'bindings')
        end

        def load_image_data(image_names, retry_count = 0)
          @host = 'https://www.mediawiki.org/w/api.php'
          response = Faraday.new.post do |req|
            req.url(@host)
            req.headers['Accept'] = 'application/json'
            req.headers['content-type'] = 'application/form-data'
            req.headers['user-agent'] = 'Ruby 2.6.4'
            req.params['format'] = 'json'
            req.params['action'] = 'query'
            req.params['prop'] = 'imageinfo|categories|categoryinfo'
            req.params['iiprop'] = 'url|extmetadata|size|canonicaltitle'
            req.params['titles'] = image_names.join('|')
          end

          if response.success?
            JSON.parse(response.body).dig('query', 'pages').values
          elsif response.status.to_i == 504 && retry_count < 5 # server is request rate limited!
            sleep(20)
            load_image_data(image_names, retry_count + 1)
          else
            raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}", response) unless response.success?
          end
        rescue Net::ReadTimeout
          sleep(20)
          load_image_data(image_names, retry_count + 1)
        end

        def load_classification_data(root_class)
          response = Faraday.new.post do |req|
            req.url(@host)
            req.headers['Accept'] = 'application/sparql-results+json'
            req.headers['content-type'] = 'application/sparql-query'
            req.headers['user-agent'] = 'Ruby 2.6.4'
            req.body = <<-EOS
              SELECT DISTINCT ?class ?classLabel ?parent ?parentLabel WHERE {
                ?class wdt:P279* wd:#{root_class}.
                OPTIONAL { ?class wdt:P279 ?parent }
                SERVICE wikibase:label { bd:serviceParam wikibase:language "de,en". }
              }
            EOS
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}", response) unless response.success?
          JSON.parse(response.body).dig('results', 'bindings')
        end
      end
    end
  end
end
