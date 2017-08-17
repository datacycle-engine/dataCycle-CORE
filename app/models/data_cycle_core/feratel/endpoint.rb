class DataCycleCore::Feratel::Endpoint
  def initialize(pos_code: nil, company_code: nil, range_code: nil, db_code: nil, range_id: nil, sales_channel_id: nil)
    @pos_code = pos_code
    @company_code = company_code
    @range_code = range_code
    @db_code = db_code
    @range_id = range_id
    @sales_channel_id = sales_channel_id
  end

  def load_events(start_date = Date.today.beginning_of_month, end_date = Date.today.end_of_month)
    ranges = (start_date..end_date).map { |d| 
        [start_date, d.beginning_of_month].max 
      }.uniq.map { |d| 
        d .. [d.end_of_month, Date.today + 11.weeks].min
      }

    if ranges.count > 1
      ranges.each do |range| 
        load_events(range.first, range.last)
      end
    else
      conn = Faraday.new

      response = conn.post do |req|
        req.url 'http://interface.deskline.net//DSI/BasicData.asmx/GetData'
        req.body = {
          "xmlString" => create_event_request_xml(start_date, end_date)
        }
      end

      envelop = Nokogiri::XML(response.body)

      data = Nokogiri::XML(envelop.children.first.content)
      data.remove_namespaces!

      data.xpath('//Event').map(&:to_hash).each do |raw_event_data|
        event = DataCycleCore::Feratel::Event.find_or_initialize_by('external_id': raw_event_data['Id'])
        event.dump = raw_event_data
        event.save!
      end
    end
  end

  def create_event_request_xml(start_date, end_date)
"<?xml version=\"1.0\" encoding=\"utf-8\"?>
<FeratelDsiRQ xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://interface.deskline.net/DSI/XSD\">
    <Request Originator=\"#{@pos_code}\" Company=\"#{@company_code}\" Language=\"de\"> 
        <Range Code=\"#{@range_code}\">
            <Item Id=\"#{@range_id}\" />
        </Range>
        <BasicData>
          <Filters>
              <Events Start=\"#{start_date.strftime('%Y-%m-%d')}\" End=\"#{end_date.strftime('%Y-%m-%d')}\" Systems=\"T \" />
              <Languages>
                  <Language Value=\"de\" />
              </Languages>
          </Filters>
          <Events>
            <Details DateFrom=\"1980-01-01\" />
            <Documents DateFrom=\"1980-01-01\" Systems=\"L T\" />
            <Descriptions DateFrom=\"1980-01-01\" Systems=\"L T\" />
            <Links DateFrom=\"1980-01-01\" />
            <Facilities DateFrom=\"1980-01-01\" />
            <Addresses DateFrom=\"1980-01-01\" />
            <HandicapFacilities DateFrom=\"1980-01-01\" />
            <HandicapClassifications DateFrom=\"1980-01-01\" />
          </Events>
        </BasicData>
    </Request>
</FeratelDsiRQ>"
  end

end
