class DataCycleCore::Feratel::Endpoint
  def initialize(pos_code: nil, company_code: nil, range_code: nil, db_code: nil, range_id: nil, sales_channel_id: nil)
    @pos_code = pos_code
    @company_code = company_code
    @range_code = range_code
    @db_code = db_code
    @range_id = range_id
    @sales_channel_id = sales_channel_id
  end

  def load_locations
    load_data(:locations)
  end

  def load_holiday_themes
    load_data(:holiday_themes)
  end

  def load_infrastructure_topics
    load_data(:infrastructure_topics)
  end

  def load_custom_attributes
    load_data(:custom_attributes)
  end

  def load_facility_groups
    load_data(:facility_groups)
  end

  def load_facilities
    load_data(:facilities)
  end

  def load_rating_questions
    load_data(:rating_questions)
  end

  def load_infrastructure_items
    load_data(:infrastructure_items)
  end

  def load_additional_service_providers
    load_data(:additional_service_providers)
  end

  def load_events
    load_data(:events)
  end

  def load_data(type)
    if [:additional_service_providers, :events, :infrastructure_items].include?(type)
      url = 'http://interface.deskline.net/DSI/BasicData.asmx/GetData'
    else
      url = 'http://interface.deskline.net/DSI/KeyValue.asmx/GetKeyValues'
    end

    response = Faraday.new.post do |req|
      req.url url
      req.options.timeout = 120
      req.body = {"xmlString" => send("create_#{type}_request_xml")}
    end

    envelop = Nokogiri::XML(response.body)

    data = Nokogiri::XML(envelop.children.first.content)
    data.remove_namespaces!

    if data.xpath('//@Status').first.value != '0'
      raise data.xpath('//@Message').first.value
    else
      data
    end
  end

  def create_locations_request_xml
    create_request_xml do |xml|
      xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
        xml.Translations do
          available_locales.each do |l|
            xml.Language('Value' => l.to_s)
          end
        end

        xml.Countries('Show' => true, 'IncludeTranslations' => true)
        xml.Regions('Show' => true, 'IncludeTranslations' => true)
        xml.Towns('Show' => true, 'IncludeTranslations' => true)
        xml.Districts('Show' => true, 'IncludeTranslations' => true)
      end
    end
  end

  def create_holiday_themes_request_xml
    create_request_xml do |xml|
      xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
        xml.Translations do
          available_locales.each do |l|
            xml.Language('Value' => l.to_s)
          end
        end

        xml.HolidayThemes('Show' => true)
      end
    end
  end

  def create_infrastructure_topics_request_xml
    create_request_xml do |xml|
      xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
        xml.Translations do
          available_locales.each do |l|
            xml.Language('Value' => l.to_s)
          end
        end

        xml.InfrastructureTopics('Show' => true)
      end
    end
  end

  def create_custom_attributes_request_xml
    create_request_xml do |xml|
      xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
        xml.Translations do
          available_locales.each do |l|
            xml.Language('Value' => l.to_s)
          end
        end

        xml.CustomAttributes('Show' => true)
      end
    end
  end

  def create_facility_groups_request_xml
    create_request_xml do |xml|
      xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
        xml.Translations do
          available_locales.each do |l|
            xml.Language('Value' => l.to_s)
          end
        end

        xml.FacilityGroups('Show' => true)
      end
    end
  end

  def create_facilities_request_xml
    create_request_xml do |xml|
      xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
        xml.Translations do
          available_locales.each do |l|
            xml.Language('Value' => l.to_s)
          end
        end

        xml.Facilities('Show' => true)
      end
    end
  end

  def create_rating_questions_request_xml
    create_request_xml do |xml|
      xml.KeyValues('GetLocalValues' => true, 'DateFrom' => '2000-01-01') do
        xml.Translations do
          available_locales.each do |l|
            xml.Language('Value' => l.to_s)
          end
        end

        xml.RatingQuestions('Show' => true)
      end
    end
  end

  def create_infrastructure_items_request_xml
    create_request_xml do |xml|
      xml.BasicData do
        xml.Filters do
          xml.Infrastructure
          xml.Languages do
            available_locales.each do |l|
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

  def create_additional_service_providers_request_xml
    create_request_xml do |xml|
      xml.BasicData do
        xml.Filters do
          xml.ServiceProvider('Type' => 'AdditionalService')
          xml.Languages do
            available_locales.each do |l|
              xml.Language('Value' => l.to_s)
            end
          end
        end

        xml.ServiceProviders('ShowDataOwner' => true, 'IncludeVTInfo' => true) do
          xml.Details('DateFrom' => '1980-01-01', 'IncludeTranslations' => true)
          xml.Documents('DateFrom' => '1980-01-01')
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

  def create_events_request_xml
    create_request_xml do |xml|
      xml.BasicData do
        xml.Filters do
          xml.Events('Start' => (Date.today - 1.years).strftime('%Y-%m-%d'), 'End' => (Date.today + 10.years).strftime('%Y-%m-%d'))
          xml.Languages do
            available_locales.each do |l|
              xml.Language('Value' => l.to_s)
            end
          end
        end

        xml.Events('ShowDataOwner' => true) do
          xml.Details('DateFrom' => "1980-01-01")
          xml.Documents('DateFrom' => "1980-01-01")
          xml.Descriptions('DateFrom' => "1980-01-01")
          xml.Links('DateFrom' => "1980-01-01")
          xml.Facilities('DateFrom' => "1980-01-01")
          xml.Addresses('DateFrom' => "1980-01-01")
          xml.CustomAttributes('DateFrom' => "1980-01-01")
          xml.HandicapFacilities('DateFrom' => "1980-01-01")
          xml.HandicapClassifications('DateFrom' => "1980-01-01")
        end
      end
    end
  end

  def create_request_xml
    Nokogiri::XML::Builder.new { |xml|
      xml.FeratelDsiRQ("xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
                       "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
                       "xmlns" => "http://interface.deskline.net/DSI/XSD") do
        xml.Request("Originator" => @pos_code, "Company" => @company_code) do
          xml.Range("Code" => @range_code) do
            xml.Item("Id" => @range_id)
          end

          yield(xml)
        end
      end
    }.to_xml
  end

  def available_locales
    I18n.available_locales.map(&:to_s).reject { |l| l.include?('-') }
  end
end
