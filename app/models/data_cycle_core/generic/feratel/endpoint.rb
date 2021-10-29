# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      class Endpoint
        include EndpointLoadRanges
        include EndpointDownloadXml
        include EndpointUpdateXml
        include EndpointDeletedXml
        include EndpointGlobalDownloader
        include EndpointSearch

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
          @endpoint_url = options[:endpoint_url] || 'http://interface.deskline.net'
        end

        def faraday
          Faraday.new(request: { timeout: 1200 }) do |f|
            f.request :url_encoded
            f.request :retry, max: 7, interval: 60, backoff_factor: 2, exceptions: [StandardError]

            f.response :follow_redirects
          end
        end

        # basic download of data
        def additional_service_types(lang: :de)
          enumerate_items(:additional_service_types, '//AdditionalServiceTypes/AdditionalServiceType', lang: lang)
        end

        def brochures(lang: :de)
          enumerate_items(:brochures, '//ShopItems/ShopItem', lang: lang)
        end

        def categories(lang: :de)
          enumerate_items(:categories, '//Categories/Category', lang: lang)
        end

        def classifications(lang: :de)
          enumerate_items(:classifications, '//Classifications/Classification', lang: lang)
        end

        def creative_commons(lang: :de)
          enumerate_items(:creative_commons, '//CreativeCommons/CreativeCommon', lang: lang)
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

        def guest_cards(lang: :de)
          enumerate_items(:guest_cards, '//GuestCards/GuestCard', lang: lang)
        end

        def guest_card_classifications(lang: :de)
          enumerate_items(:guest_card_classifications, '//GuestCardClassifications/GuestCardClassification', lang: lang)
        end

        def hot_spots(lang: :de)
          enumerate_items(:hot_spots, '//HotSpot', lang: lang)
        end

        def handicap_groups(lang: :de)
          enumerate_items(:handicap_groups, '//HandicapGroup', lang: lang)
        end

        def handicap_types(lang: :de)
          enumerate_items(:handicap_types, '//HandicapType', lang: lang)
        end

        def handicap_classifications(lang: :de)
          enumerate_items(:handicap_classifications, '//HandicapClassification', lang: lang)
        end

        def handicap_facility_groups(lang: :de)
          enumerate_items(:handicap_facility_groups, '//HandicapFacilityGroup', lang: lang)
        end

        def handicap_facilities(lang: :de)
          enumerate_items(:handicap_facilities, '//HandicapFacility', lang: lang)
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

        def link_types(lang: :de)
          enumerate_items(:link_types, '//LinkType', lang: lang)
        end

        def locations(lang: :de)
          enumerate_items(:locations, '//Location', lang: lang)
        end

        def marketing_groups(lang: :de)
          enumerate_items(:marketing_groups, '//MarketingGroup', lang: lang)
        end

        def rating_questions(lang: :de)
          enumerate_items(:rating_questions, '//RatingQuestions/RatingQuestion', lang: lang)
        end

        def rating_visitors(lang: :de)
          enumerate_items(:rating_visitors, '//RatingVisitor', lang: lang)
        end

        def shop_item_groups(lang: :de)
          enumerate_items(:shop_item_groups, '//ShopItemGroup', lang: lang)
        end

        def stars(lang: :de)
          enumerate_items(:stars, '//Stars/Star', lang: lang)
        end

        def serial_events(lang: :de)
          enumerate_items(:serial_events, '//SerialEvents/SerialEvent', lang: lang)
        end

        def fallback_languages(lang: :de)
          enumerate_language_items(:fallback_languages, '//Language', lang: lang)
        end

        def visitor_tax(lang: :de)
          enumerate_language_items(:visitor_tax, '//VisitorTax', lang: lang)
        end

        def service_codes(lang: :de)
          enumerate_language_items(:service_codes, '//ServiceCode', lang: lang, item_field: 'srcCode')
        end

        # download of large data with temporary file
        def packages(lang: :de)
          enumerate_items_large(:packages, '&lt\;Package Id', lang: lang)
        end

        def package_containers(lang: :de)
          enumerate_items_large(:package_containers, '&lt\;Package Id', lang: lang)
        end

        # two stage download, first generate an index and then page the index to download full data
        def infrastructure_items(lang: :de, forced_updates: [])
          enumerate_two_stages(:infrastructure_items, '//Infrastructure/InfrastructureItem', '//ChangedInfrastructures/Infrastructure', lang: lang, forced_updates: forced_updates)
        end

        def additional_service_providers(lang: :de, forced_updates: [])
          enumerate_two_stages(:additional_service_providers, '//ServiceProviders/ServiceProvider', '//ChangedServiceProviders/ServiceProvider', lang: lang, forced_updates: forced_updates)
        end

        def events(lang: :de, forced_updates: [])
          enumerate_two_stages(:events, '//Events/Event', '//ChangedEvents/Event', lang: lang, forced_updates: forced_updates)
        end

        def accommodations(lang: :de, forced_updates: [])
          enumerate_two_stages(:accommodations, '//ServiceProviders/ServiceProvider', '//ChangedServiceProviders/ServiceProvider', lang: lang, forced_updates: forced_updates)
        end

        def mark_deleted_accommodations(lang: :de, deleted_from:)
          enumerate_items(:mark_deleted_accommodations, '//DeletedItems/Item', lang: lang, deleted_from: deleted_from)
        end

        def mark_deleted_events(lang: :de, deleted_from:)
          enumerate_items(:mark_deleted_events, '//DeletedItems/Item', lang: lang, deleted_from: deleted_from)
        end

        def mark_deleted_infrastructure_items(lang: :de, deleted_from:)
          enumerate_items(:mark_deleted_infrastructure_items, '//DeletedItems/Item', lang: lang, deleted_from: deleted_from)
        end

        def mark_updated(lang: :de, deleted_from: nil)
          load_deleted_related_items(lang: lang, deleted_from: deleted_from)
        end

        def load_deleted_related_items(lang: :de, deleted_from: nil)
          item_ids = []
          ['RG', 'DI', 'TO'].each do |range_code|
            load_range_ids(range_code).each do |range_id|
              load_updated_data(lang: lang, range_code: range_code, range_ids: range_id, deleted_from: deleted_from)&.each do |item|
                item_ids << item['Id'] unless item_ids.include?(item['Id'])
              end
            end
          end
          item_ids.sort
        end

        def load_updated_data(lang: :de, range_code: 'RG', range_ids: @primary_range_id, deleted_from: nil, retry_count: 0)
          url = "#{@endpoint_url}/DSI/BasicData.asmx/GetData"
          request_parameters = send('create_mark_updated_request_xml', range_code: range_code, range_ids: range_ids, deleted_from: deleted_from)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = faraday.post(url) do |req|
            req.url url
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)
          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          if data.xpath('//@Status').first.value == '1' && data.xpath('//@Message').first.value == 'Organisation access denied.'
            nil
          elsif data.xpath('//@Status').first.value != '0'
            raise data.xpath('//@Message').first.value
          else
            data
              .xpath('//Result/DeletedItems')
              .map { |i| Array.wrap(i.to_hash['Item']) }
              .inject(&:+)
          end
        rescue StandardError
          raise if retry_count > 5
          sleep(3)
          load_updated_data(lang: lang, range_code: range_code, range_ids: range_ids, deleted_from: deleted_from, retry_count: retry_count + 1)
        end

        def enumerate_items(type, xpath, lang: :de, deleted_from: nil)
          Enumerator.new do |yielder|
            item_ids = []
            ['RG', 'DI', 'TO'].each do |range_code|
              load_range_ids(range_code).each do |range_id|
                load_data(type, lang: lang, range_code: range_code, range_ids: range_id, deleted_from: deleted_from)&.xpath(xpath)&.each do |xml_data|
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

        def enumerate_default_items(type, xpath, lang: :de)
          Enumerator.new do |yielder|
            item_ids = []
            range_code = @primary_range_code
            range_id = @primary_range_id

            load_data(type, lang: lang, range_code: range_code, range_ids: range_id)&.xpath(xpath)&.each do |xml_data|
              item = { '_Type' => xml_data.parent.name.singularize }.merge(xml_data.to_hash)
              unless item_ids.include?(item['Id'] || item['Order'])
                item_ids << item['Id'] || item['Order']
                yielder << item
              end
            end
          end
        end

        def enumerate_language_items(type, xpath, lang: :de, item_field: 'Code')
          Enumerator.new do |yielder|
            item_ids = []
            range_code = @primary_range_code
            range_id = @primary_range_id

            load_data(type, lang: lang, range_code: range_code, range_ids: range_id)&.xpath(xpath)&.each do |xml_data|
              item = { '_Type' => xml_data.parent.name.singularize }.merge(xml_data.to_hash)
              unless item_ids.include?(item[item_field])
                item_ids << item[item_field]
                yielder << item
              end
            end
          end
        end

        def enumerate_two_stages(type, xpath, changed_xpath, lang: :de, forced_updates: [])
          # load all relevant item_ids
          item_hash = {}
          min_index = @params[:min_count] || 0
          max_index = @params[:max_count] || (2**(0.size * 8 - 2) - 1)
          external_keys = @params[:external_keys]
          changed_from = @params[:changed_from]
          all_data = load_range_ids_new.map { |range_code, range_id|
            data_loaded =
              if changed_from.present?
                load_changed_data(type, lang: lang, range_code: range_code, range_ids: range_id, changed_from: changed_from)&.xpath(changed_xpath)
              else
                load_data(type, lang: lang, range_code: range_code, range_ids: range_id, index: true)&.xpath(xpath)
              end
            (data_loaded || []).map { |xml_raw_data|
              next if external_keys.present? && !xml_raw_data['Id'].in?(external_keys)
              [xml_raw_data['Id'], range_code, range_id]
            }.compact
          }.inject(:+)
          (forced_updates + all_data)[min_index...max_index]&.each { |i| item_hash[i[1..2]] = (item_hash[i[1..2]] || []).push(i[0]) }

          # load item details
          Enumerator.new do |yielder|
            item_ids = []
            item_hash.each do |range, ids|
              ids.each_slice(@per) do |id_slice|
                load_data_item(type, lang: lang, range_code: range[0], range_ids: range[1], item_ids: id_slice)&.xpath(xpath)&.each do |xml_data|
                  item = {
                    '_Type' => xml_data.parent.name.singularize,
                    '_RangeCode' => range[0],
                    '_RangeId' => range[1]
                  }.merge(xml_data.to_hash)
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

        def load_data(type, lang: :de, range_code: 'RG', range_ids: @primary_range_id, index: false, retry_count: 0, deleted_from: nil)
          method_name = index ? "create_#{type}_index_request_xml" : "create_#{type}_request_xml"

          if [:additional_service_providers, :events, :infrastructure_items, :accommodations, :packages, :package_containers, :brochures].include?(type)
            url = "#{@endpoint_url}/DSI/BasicData.asmx/GetData"
            request_parameters = send(method_name, lang: lang, range_code: range_code, range_ids: range_ids)
          elsif [:mark_deleted_events, :mark_deleted_accommodations, :mark_deleted_infrastructure_items].include?(type)
            url = "#{@endpoint_url}/DSI/BasicData.asmx/GetData"
            request_parameters = send(method_name, range_code: range_code, range_ids: range_ids, deleted_from: deleted_from)
          else
            url = "#{@endpoint_url}/DSI/KeyValue.asmx/GetKeyValues"
            request_parameters = send(method_name, lang: lang, range_code: range_code, range_ids: range_ids)
          end

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = faraday.post do |req|
            req.url url
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)
          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          if data.xpath('//@Status').first.value == '1' && data.xpath('//@Message').first.value == 'Organisation access denied.'
            nil
          elsif data.xpath('//@Status').first.value != '0'
            raise data.xpath('//@Message').first.value
          else
            data
          end
        rescue StandardError
          raise if retry_count > 5
          sleep(3)
          load_data(type, lang: lang, range_code: range_code, range_ids: range_ids, index: index, retry_count: retry_count + 1)
        end

        def load_data_item(type, lang: :de, range_code: 'RG', range_ids: @primary_range_id, item_ids:, retry_count: 0)
          url = "#{@endpoint_url}/DSI/BasicData.asmx/GetData"
          request_parameters = send("create_#{type}_request_xml", lang: lang, range_code: range_code, range_ids: range_ids, item_ids: item_ids)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = faraday.post(url) do |req|
            req.url url
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)
          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          if data.xpath('//@Status').first.value == '1' && data.xpath('//@Message').first.value == 'Organisation access denied.'
            nil
          elsif data.xpath('//@Status').first.value != '0'
            raise data.xpath('//@Message').first.value
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
            url = "#{@endpoint_url}/DSI/BasicData.asmx/GetData"
          else
            url = "#{@endpoint_url}/DSI/KeyValue.asmx/GetKeyValues"
          end

          request_parameters = send("create_#{type}_request_xml", lang: lang, range_code: range_code, range_ids: range_ids)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = faraday.post(url) do |req|
            req.url url
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
            raise StandardError, response.body if envelop.children.first&.try(:name) == 'html' || envelop.children.first&.try(:name) == 'HTML'

            data = Nokogiri::XML(envelop.children.first.content)
            data.remove_namespaces!
            raise data.xpath('//@Message').first.value if data.xpath('//@Status').first.value != '0'
          end
          data_array.compact
        end

        def load_changed_data(type, lang: :de, range_code: 'RG', range_ids: @primary_range_id, changed_from:, retry_count: 0)
          url = "#{@endpoint_url}/DSI/BasicData.asmx/GetData"
          request_parameters = send("updated_#{type}_request_xml", lang: lang, range_code: range_code, range_ids: range_ids, changed_from: changed_from)

          # puts Nokogiri::XML(request_parameters, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          response = faraday.post(url) do |req|
            req.url url
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)
          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          if data.xpath('//@Status').first.value == '1' && data.xpath('//@Message').first.value == 'Organisation access denied.'
            nil
          elsif data.xpath('//@Status').first.value != '0'
            raise data.xpath('//@Message').first.value
          else
            data
          end
        rescue StandardError
          raise if retry_count > 5
          sleep(3)
          load_changed_data(type, lang: lang, range_code: range_code, range_ids: range_ids, changed_from: changed_from, retry_count: retry_count + 1)
        end
      end
    end
  end
end
