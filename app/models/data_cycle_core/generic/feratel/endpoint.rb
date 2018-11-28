# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      class Endpoint
        def initialize(pos_code: nil, company_code: nil, range_code: nil, range_id: nil, **options)
          @pos_code = pos_code
          @company_code = company_code
          @primary_range_code = range_code
          @primary_range_id = range_id
          @options = options
          @read_type = options[:read_type] if options[:read_type].present?
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
                code => mongo.where({ 'dump.de._Type' => range_type(code) }).map { |r| r.dump['de']['Id'] }
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

        def categories(lang: :de)
          enumerate_items(:categories, '//Category', lang: lang)
        end

        def locations(lang: :de)
          enumerate_items(:locations, '//Location', lang: lang)
        end

        def holiday_themes(lang: :de)
          enumerate_items(:holiday_themes, '//HolidayTheme', lang: lang)
        end

        def infrastructure_types(lang: :de)
          enumerate_items(:infrastructure_types, '//InfrastructureType', lang: lang)
        end

        def infrastructure_topics(lang: :de)
          enumerate_items(:infrastructure_topics, '//InfrastructureTopic', lang: lang)
        end

        def custom_attributes(lang: :de)
          enumerate_items(:custom_attributes, '//CustomAttribute', lang: lang)
        end

        def facility_groups(lang: :de)
          enumerate_items(:facility_groups, '//FacilityGroup', lang: lang)
        end

        def facilities(lang: :de)
          enumerate_items(:facilities, '//Facility', lang: lang)
        end

        def stars(lang: :de)
          enumerate_items(:stars, '//Star', lang: lang)
        end

        def classifications(lang: :de)
          enumerate_items(:classifications, '//Classification', lang: lang)
        end

        def rating_questions(lang: :de)
          enumerate_items(:rating_questions, '//RatingQuestion', lang: lang)
        end

        def infrastructure_items(lang: :de)
          enumerate_items(:infrastructure_items, '//InfrastructureItem', lang: lang)
        end

        def additional_service_providers(lang: :de)
          enumerate_items(:additional_service_providers, '//ServiceProvider', lang: lang)
        end

        def events(lang: :de)
          enumerate_items(:events, '//Event', lang: lang)
        end

        def accommodations(lang: :de)
          enumerate_items(:accommodations, '//ServiceProvider', lang: lang)
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

        def load_data(type, lang: :de, range_code: 'RG', range_ids: @range_id)
          if [:additional_service_providers, :events, :infrastructure_items, :accommodations].include?(type)
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
            req.options.timeout = 120
            req.body = { 'xmlString' => request_parameters }
          end

          envelop = Nokogiri::XML(response.body)

          data = Nokogiri::XML(envelop.children.first.content)
          data.remove_namespaces!

          raise data.xpath('//@Message').first.value if data.xpath('//@Status').first.value != '0'
          data
        end

        def create_categories_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.Categories('Show' => true)
          end
        end

        def create_locations_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.Countries('Show' => true, 'IncludeTranslations' => true)
            xml.Regions('Show' => true, 'IncludeTranslations' => true)
            xml.Towns('Show' => true, 'IncludeTranslations' => true)
            xml.Districts('Show' => true, 'IncludeTranslations' => true)
          end
        end

        def create_holiday_themes_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.HolidayThemes('Show' => true)
          end
        end

        def create_infrastructure_types_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.InfrastructureTypes('Show' => true)
          end
        end

        def create_infrastructure_topics_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.InfrastructureTopics('Show' => true)
          end
        end

        def create_custom_attributes_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.CustomAttributes('Show' => true)
          end
        end

        def create_facility_groups_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.FacilityGroups('Show' => true)
          end
        end

        def create_facilities_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.Facilities('Show' => true)
          end
        end

        def create_stars_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.Stars('Show' => true)
          end
        end

        def create_classifications_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.Classifications('Show' => true)
          end
        end

        def create_rating_questions_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_key_value_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.RatingQuestions('Show' => true)
          end
        end

        def create_infrastructure_items_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.Infrastructure
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Infrastructure('ShowDataOwner' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeMainTopicId' => true)
                xml.Documents('DateFrom' => '1980-01-01')
                xml.Descriptions('DateFrom' => '1980-01-01')
                xml.Links('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01')
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_additional_service_providers_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.ServiceProvider('Type' => 'AdditionalService')
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.ServiceProviders('ShowDataOwner' => true, 'IncludeVTInfo' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01')
                xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01', 'GetSettlementAddresses' => true)
                xml.RatingsAverage('DateFrom' => '1980-01-01')
                xml.CustomAttributes('DateFrom' => '1980-01-01')
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.AdditionalServices do
                  xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  xml.Documents('DateFrom' => '1980-01-01')
                  xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  xml.Facilities('DateFrom' => '1980-01-01')
                  xml.AdditionalProducts do
                    xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                  end
                end
              end
            end
          end
        end

        def create_events_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
          create_request_xml(range_code: range_code, range_ids: range_ids) do |xml|
            xml.BasicData do
              xml.Filters do
                xml.Events('Start' => (Time.zone.today - 1.year).strftime('%Y-%m-%d'),
                           'End' => (Time.zone.today + 10.years).strftime('%Y-%m-%d'))
                xml.Languages do
                  Array(lang).each do |l|
                    xml.Language('Value' => l.to_s)
                  end
                end
              end

              xml.Events('ShowDataOwner' => true) do
                xml.Details('DateFrom' => '1980-01-01')
                xml.Documents('DateFrom' => '1980-01-01')
                xml.Descriptions('DateFrom' => '1980-01-01')
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

        def create_accommodations_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
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

              xml.ServiceProviders('ShowDataOwner' => true, 'IncludeVTInfo' => true) do
                xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Documents('DateFrom' => '1980-01-01', 'IncludeResolution' => true)
                xml.Descriptions('DateFrom' => '1980-01-01')
                xml.Links('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
                xml.Facilities('DateFrom' => '1980-01-01')
                xml.Addresses('DateFrom' => '1980-01-01', 'GetSettlementAddresses' => true)
                xml.HotSpots('DateFrom' => '1980-01-01')
                xml.HandicapFacilities('DateFrom' => '1980-01-01')
                xml.HandicapClassifications('DateFrom' => '1980-01-01')
                xml.GTC('DateFrom' => '1980-01-01')
              end
            end
          end
        end

        def create_key_value_request_xml(lang: :de, range_code: 'RG', range_ids: [@range_id])
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
