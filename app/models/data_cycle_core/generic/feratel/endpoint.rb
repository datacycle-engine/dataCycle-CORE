# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      class Endpoint
        def initialize(pos_code: nil, company_code: nil, range_code: nil, range_id: nil, sales_channel_id: nil, **options)
          @pos_code = pos_code
          @company_code = company_code
          @primary_range_code = range_code
          @primary_range_id = range_id
          @sales_channel_id = sales_channel_id
          @read_type = options[:read_type] if options[:read_type].present?
          @per = 100
          @options = options[:options] || {}
          @params = @options[:params] || {}
        end

        # basic download of data
        def categories(lang: :de)
          enumerate_items(:categories, '//Categories/Category', lang: lang)
        end

        def classifications(lang: :de)
          enumerate_items(:classifications, '//Classifications/Classification', lang: lang)
        end

        def custom_attributes(lang: :de)
          enumerate_items(:custom_attributes, '//CustomAttributes/CustomAttribute', lang: lang)
        end

        def facilities(lang: :de)
          enumerate_items(:facilities, '//Facilities/Facility', lang: lang)
        end

        def facility_groups(lang: :de)
          enumerate_items(:facility_groups, '//FacilityGroups/FacilityGroup', lang: lang)
        end

        def holiday_themes(lang: :de)
          enumerate_items(:holiday_themes, '//HolidayThemes/HolidayTheme', lang: lang)
        end

        def infrastructure_topics(lang: :de)
          enumerate_items(:infrastructure_topics, '//InfrastructureTopics/InfrastructureTopic', lang: lang)
        end

        def infrastructure_types(lang: :de)
          enumerate_items(:infrastructure_types, '//InfrastructureTypes/InfrastructureType', lang: lang)
        end

        def locations(lang: :de)
          enumerate_items(:locations, '//Location', lang: lang)
        end

        def rating_questions(lang: :de)
          enumerate_items(:rating_questions, '//RatingQuestions/RatingQuestion', lang: lang)
        end

        def serial_events(lang: :de)
          enumerate_items(:serial_events, '//SerialEvents/SerialEvent', lang: lang)
        end

        def stars(lang: :de)
          enumerate_items(:stars, '//Stars/Star', lang: lang)
        end

        # download of large data with temporary file
        def packages(lang: :de)
          enumerate_items_large(:packages, '&lt\;Package Id', lang: lang)
        end

        def package_containers(lang: :de)
          enumerate_items_large(:package_containers, '&lt\;Package Id', lang: lang)
        end

        # two stage download, first generate an index and then page the index to download full data
        def infrastructure_items(lang: :de)
          enumerate_two_stages(:infrastructure_items, '//Infrastructure/InfrastructureItem', lang: lang)
        end

        def additional_service_providers(lang: :de)
          enumerate_two_stages(:additional_service_providers, '//ServiceProviders/ServiceProvider', lang: lang)
        end

        def events(lang: :de)
          enumerate_two_stages(:events, '//Events/Event', lang: lang)
        end

        def accommodations(lang: :de)
          enumerate_two_stages(:accommodations, '//ServiceProviders/ServiceProvider', lang: lang)
        end

        def load_range_ids(range_code = 'RG')
          range_ids = load_location_range_ids(
            @options.dig(:options, :location_range_codes)
          )

          if range_ids.include?(range_code)
            range_ids[range_code]
          elsif range_code == @primary_range_code
            [@primary_range_id]
          else
            []
          end
        end

        def load_location_range_ids(range_codes)
          raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?
          range_codes ||= []

          DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            range_codes.map(&:to_s).uniq.map { |code|
              {
                code => mongo.where({ 'dump.de._Type' => range_type(code) }).map { |r| r.dump['de']['Id'] } # , 'dump.de.ParentID' => { '$ne' => '00000000-0000-0000-0000-000000000000' }
              }
            }.reduce({}, &:merge)
          end
        end

        def range_type(range_code)
          case range_code
          when 'RG' then 'Region'
          when 'DI' then 'District'
          when 'TO' then 'Town'
          end
        end

        def enumerate_items(type, xpath, lang: :de)
          Enumerator.new do |yielder|
            item_ids = []
            ['RG', 'DI', 'TO'].each do |range_code|
              load_range_ids(range_code).each do |range_id|
                load_data(type, lang: lang, range_code: range_code, range_ids: range_id).xpath(xpath).each do |xml_data|
                  item = { '_Type' => xml_data.parent.name.singularize }.merge(xml_data.to_hash)
                  unless item_ids.include?(item['Id'] || item['Order'])
                    item_ids << item['Id'] || item['Order']
                    yielder << item
                  end
                end
              end
            end
          end
        end

        def load_range_ids_new
          raise ArgumentError, 'missing read_type for loading location ranges' if @read_type.nil?
          range_types = { 'Region' => 'RG', 'District' => 'DI', 'Town' => 'TO' }
          range_parameters = DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            mongo.where({ 'dump.de.ParentID' => /#{@primary_range_id}/i })
              .to_a.map { |r| [range_types[r.dump['de']['_Type']], r.dump['de']['Id']] }
              .presence
          end
          (range_parameters.presence || []) + [[@primary_range_code, @primary_range_id]]
        end

        def enumerate_two_stages(type, xpath, lang: :de)
          # load all relevant item_ids
          item_hash = {}
          min_index = @params[:min_count] || 0
          max_index = @params[:max_count] || (2**(0.size * 8 - 2) - 1)
          load_range_ids_new.map { |range_code, range_id|
            load_data(type, lang: lang, range_code: range_code, range_ids: range_id, index: true).xpath(xpath).map do |xml_raw_data|
              [xml_raw_data['Id'], range_code, range_id]
            end
          }.inject(:+)[min_index...max_index]&.each { |i| item_hash[i[1..2]] = (item_hash[i[1..2]] || []).push(i[0]) }

          # load item details
          Enumerator.new do |yielder|
            item_ids = []
            item_hash.each do |range, ids|
              ids.each_slice(@per) do |id_slice|
                load_data_item(type, lang: lang, range_code: range[0], range_ids: range[1], item_ids: id_slice).xpath(xpath).each do |xml_data|
                  item = { '_Type' => xml_data.parent.name.singularize }.merge(xml_data.to_hash)
                  unless item_ids.include?(item['Id'] || item['Order'])
                    item_ids << item['Id'] || item['Order']
                    yielder << item
                  end
                end
              end
            end
          end
        end

        def enumerate_items_large(type, pattern, lang: :de)
          Enumerator.new do |yielder|
            item_ids = []
            load_range_ids_new.each do |range_code, range_id|
              load_data_large(type, lang: lang, range_code: range_code, range_ids: range_id, pattern: pattern).each do |xml_raw_data|
                xml_data = Nokogiri::XML.parse(Nokogiri::HTML.parse(xml_raw_data))
                item = { '_Type' => xml_data.root.name.singularize }.merge(xml_data.root.to_hash)
                unless item_ids.include?(item['Id'] || item['Order'])
                  item_ids << item['Id'] || item['Order']
                  yielder << item
                end
              end
            end
          end
        end

        def load_data(type, lang: :de, range_code: 'RG', range_ids: @primary_range_id, index: false, retry_count: 0)
          if [:additional_service_providers, :events, :infrastructure_items, :accommodations, :packages, :package_containers].include?(type)
            url = 'http://interface.deskline.net/DSI/BasicData.asmx/GetData'
          else
            url = 'http://interface.deskline.net/DSI/KeyValue.asmx/GetKeyValues'
          end

          method_name = index ? "create_#{type}_index_request_xml" : "create_#{type}_request_xml"
          request_parameters = send(method_name, lang: lang, range_code: range_code, range_ids: range_ids)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = Faraday.new.post do |req|
            req.url url
            req.options.timeout = 1200
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)

          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          if data.xpath('//@Status').first.value != '0'
            raise data.xpath('//@Message').first.value if retry_count > 5
            sleep(3)
            load_data(type, lang: lang, range_code: range_code, range_ids: range_ids, index: index, retry_count: retry_count + 1)
          else
            data
          end
        rescue StandardError
          raise if retry_count > 5
          sleep(3)
          load_data(type, lang: lang, range_code: range_code, range_ids: range_ids, index: index, retry_count: retry_count + 1)
        end

        def load_data_item(type, lang: :de, range_code: 'RG', range_ids: @primary_range_id, item_ids:, retry_count: 0)
          url = 'http://interface.deskline.net/DSI/BasicData.asmx/GetData'
          request_parameters = send("create_#{type}_request_xml", lang: lang, range_code: range_code, range_ids: range_ids, item_ids: item_ids)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = Faraday.new.post do |req|
            req.url url
            req.options.timeout = 1200
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)
          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          if data.xpath('//@Status').first.value != '0'
            raise data.xpath('//@Message').first.value if retry_count > 5
            sleep(3)
            load_data_item(type, lang: lang, range_code: range_code, range_ids: range_ids, item_ids: item_ids, retry_count: retry_count + 1)
          else
            data
          end
        rescue StandardError
          raise if retry_count > 5
          sleep(3)
          load_data_item(type, lang: lang, range_code: range_code, range_ids: range_ids, item_ids: item_ids, retry_count: retry_count + 1)
        end

        def load_data_large(type, lang: :de, range_code: 'RG', range_ids: @primary_range_id, pattern:)
          if [:additional_service_providers, :events, :infrastructure_items, :accommodations, :packages, :package_containers].include?(type)
            url = 'http://interface.deskline.net/DSI/BasicData.asmx/GetData'
          else
            url = 'http://interface.deskline.net/DSI/KeyValue.asmx/GetKeyValues'
          end

          request_parameters = send("create_#{type}_request_xml", lang: lang, range_code: range_code, range_ids: range_ids)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = Faraday.new.post do |req|
            req.url url
            req.options.timeout = 1200
            req.body = { 'xmlString' => request_parameters }
          end

          tempfile = Tempfile.new('feratel')
          tempfile.binmode
          tempfile.write(response.body)
          tempfile.close
          data_array = []
          File.open(tempfile.path, 'r').each_chunk(pattern) do |chunk|
            data_array.push(chunk)
          end
          tempfile.unlink

          if data_array[0].nil?
            envelop = Nokogiri::XML.parse(response.body)
            raise StandardError, response.body if envelop.children.first&.try(:name) == 'html'

            data = Nokogiri::XML(envelop.children.first.content)
            data.remove_namespaces!
            raise data.xpath('//@Message').first.value if data.xpath('//@Status').first.value != '0'
          end
          data_array.compact
        end

        def create_categories_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Categories('Show' => true)
          end
        end

        def create_locations_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Countries('Show' => true, 'IncludeTranslations' => true)
            xml.Regions('Show' => true, 'IncludeTranslations' => true)
            xml.Towns('Show' => true, 'IncludeTranslations' => true)
            xml.Districts('Show' => true, 'IncludeTranslations' => true)
          end
        end

        def create_holiday_themes_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.HolidayThemes('Show' => true)
          end
        end

        def create_infrastructure_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.InfrastructureTypes('Show' => true)
          end
        end

        def create_infrastructure_topics_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.InfrastructureTopics('Show' => true)
          end
        end

        def create_custom_attributes_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.CustomAttributes('Show' => true)
          end
        end

        def create_facility_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.FacilityGroups('Show' => true)
          end
        end

        def create_facilities_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Facilities('Show' => true)
          end
        end

        def create_stars_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Stars('Show' => true)
          end
        end

        def create_classifications_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.Classifications('Show' => true)
          end
        end

        def create_rating_questions_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.RatingQuestions('Show' => true)
          end
        end

        def create_infrastructure_items_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.Infrastructure('Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Infrastructure do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_infrastructure_items_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.PreSelectedInfrastructureIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.Infrastructure('Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Infrastructure('ShowDataOwner' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeMainTopicId' => true)
                xml.Documents('DateFrom' => '1980-01-01')
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01')
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
                xml.QualityDetails('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_additional_service_providers_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.ServiceProvider('Type' => 'AdditionalService', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_additional_service_providers_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          start_date = Time.zone.now.to_s[0..9]
          end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.PreSelectedServiceProviderIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.ServiceProvider('Type' => 'AdditionalService', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders('ShowDataOwner' => true, 'IncludeVTInfo' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01', 'GetSettlementAddresses' => true)
                xml.RatingsAverage('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.QualityDetails('DateFrom' => '1980-01-01')
                xml.HousePackageMasters('DateFrom' => '1980-01-01')
                xml.AdditionalServices do
                  xml.Details('DateFrom' => '1980-01-01')
                  xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                  xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  xml.Facilities('DateFrom' => '1980-01-01')
                  xml.HandicapClassifications('DateFrom' => '1980-01-01')
                  xml.AdditionalProducts do
                    xml.Details('DateFrom' => '1980-01-01')
                    xml.Prices('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                    # xml.PriceDetails('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                  end
                end
              end
            end
          end
        end

        def create_events_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.Events('Start' => (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                           'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d'),
                           'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Events do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_events_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.PreSelectedEventIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.Events('Start' => (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                           'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d'),
                           'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Events('ShowDataOwner' => true) do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01')
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_accommodations_index_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.ServiceProvider('Type' => 'Accommodation', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders do
                xml.Details('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_accommodations_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id], item_ids: nil)
          start_date = Time.zone.now.to_s[0..9]
          end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.PreSelectedServiceProviderIDs do
                  Array.wrap(item_ids).each do |id|
                    xml.Item(id)
                  end
                end
                xml.ServiceProvider('Type' => 'Accommodation', 'Status' => 'All')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders('ShowDataOwner' => true, 'IncludeVTInfo' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01', 'GetSettlementAddresses' => true)
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
                xml.GTC('DateFrom' => '1980-01-01')
                xml.QualityDetails('DateFrom' => '1980-01-01')
                xml.HousePackageMasters('DateFrom' => '1980-01-01')
                xml.Services do
                  xml.Details('DateFrom' => '1980-01-01')
                  # xml.Documents('DateFrom' => '1980-01-01')
                  xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                  # xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  # xml.Facilities('DateFrom' => '1980-01-01')
                  # xml.HandicapFacilities('DateFrom' => '1980-01-01')
                  xml.Products do
                    xml.Details('DateFrom' => '1980-01-01')
                    # xml.Documents('DateFrom' => '1980-01-01')
                    xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                    # xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                    xml.Prices('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id)
                    # xml.PriceDetails('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id, 'Start' => start_date, 'End' => end_date)
                    # xml.ArrivalDepartureTemplates('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id, 'Start' => start_date, 'End' => end_date)
                    # xml.Availabilities('DateFrom' => '1980-01-01', 'SalesChannel' => @sales_channel_id, 'Start' => start_date, 'End' => end_date)
                    # xml.Gaps('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                  end
                end
                xml.AdditionalServices do
                  xml.Details('DateFrom' => '1980-01-01')
                  # xml.Documents('DateFrom' => '1980-01-01')
                  xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  # xml.Facilities('DateFrom' => '1980-01-01')
                  xml.AdditionalProducts do
                    xml.Details('DateFrom' => '1980-01-01')
                    # xml.Documents('DateFrom' => '1980-01-01')
                    # xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                    xml.Prices('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                    # xml.PriceDetails('DateFrom' => '1980-01-01', 'Start' => start_date, 'End' => end_date)
                  end
                end
              end
            end
          end
        end

        def create_packages_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          # start_date = Time.zone.now.to_s[0..9]
          # end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.Packages('Status' => 'All', 'From' => '1980-01-01', 'To' => '2080-01-01')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Packages do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01')
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.Prices('DateFrom' => '1980-01-01')
                xml.ContentDescriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                # xml.Sections do
                #   xml.Details('DateFrom' => '1980-01-01')
                #   xml.Descriptions('DateFrom' => '1980-01-01')
                #   xml.Prices('DateFrom' => '1980-01-01')
                #   xml.Products do
                #     xml.Availabilities('DateFrom' => '1980-01-01')
                #     xml.Prices('DateFrom' => '1980-01-01')
                #   end
                # end
              end
            end
          end
        end

        def create_package_containers_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          # start_date = Time.zone.now.to_s[0..9]
          # end_date = (Time.zone.now + 2.years).to_s[0..9]
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.PackageContainer('From' => '1980-01-01', 'To' => '2080-01-01')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.PackageContainers do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01')
                xml.Descriptions('DateFrom' => '1980-01-01', 'Markup' => true)
                xml.Links('DateFrom' => '1980-01-01')
                xml.AssignedProducts('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_key_value_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
              xml.Translations do
                Array(lang).each do |l|
                  xml.Language('Value' => l.to_s)
                end
              end

              yield(xml)
            end
          end
        end

        def create_serial_events_request_xml(lang: :de, range_code: 'RG', range_ids: [@primary_range_id])
          create_key_value_request_xml(lang: lang, range_code: range_code, range_ids: range_ids) do |xml|
            xml.SerialEvents('Show' => true)
          end
        end

        def create_request_xml(range_code: 'RG', range_ids: @primary_range_id)
          Nokogiri::XML::Builder.new { |xml|
            xml.FeratelDsiRQ('xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                             'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                             'xmlns' => 'http://interface.deskline.net/DSI/XSD') do
              xml.Request('Originator' => @pos_code, 'Company' => @company_code) do
                xml.Range('Code' => range_code) do
                  Array(range_ids).each do |range_id|
                    xml.Item('Id' => range_id)
                  end
                end

                yield(xml)
              end
            end
          }.to_xml
        end
      end
    end
  end
end
