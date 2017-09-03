class DataCycleCore::Feratel::Endpoint
  def initialize(pos_code: nil, company_code: nil, range_code: nil, db_code: nil, range_id: nil, sales_channel_id: nil)
    @pos_code = pos_code
    @company_code = company_code
    @range_code = range_code
    @db_code = db_code
    @range_id = range_id
    @sales_channel_id = sales_channel_id
  end

  def load_events
    conn = Faraday.new

    response = conn.post do |req|
      req.url 'http://interface.deskline.net//DSI/BasicData.asmx/GetData'
      req.body = {
        "xmlString" => create_event_request_xml
      }
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

  def create_event_request_xml
"<?xml version=\"1.0\" encoding=\"utf-8\"?>
<FeratelDsiRQ xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns=\"http://interface.deskline.net/DSI/XSD\">
    <Request Originator=\"#{@pos_code}\" Company=\"#{@company_code}\">
        <Range Code=\"#{@range_code}\">
            <Item Id=\"#{@range_id}\" />
        </Range>
        <BasicData>
          <Filters>
              <Events Start=\"#{(Date.today - 1.years).strftime('%Y-%m-%d')}\" End=\"#{(Date.today + 10.years).strftime('%Y-%m-%d')}\" />
              <Languages>
                  #{DataCycleCore.available_locales.keys.map { |l| '<Language Value="' + l.to_s + '" />' }.join("\n                  ")}
              </Languages>
          </Filters>
          <Events ShowDataOwner=\"true\">
            <Details DateFrom=\"1980-01-01\" />
            <Documents DateFrom=\"1980-01-01\" />
            <Descriptions DateFrom=\"1980-01-01\" />
            <Links DateFrom=\"1980-01-01\" />
            <Facilities DateFrom=\"1980-01-01\" />
            <Addresses DateFrom=\"1980-01-01\" />
            <CustomAttributes DateFrom=\"1980-01-01\" />
            <HandicapFacilities DateFrom=\"1980-01-01\" />
            <HandicapClassifications DateFrom=\"1980-01-01\" />
          </Events>
        </BasicData>
    </Request>
</FeratelDsiRQ>"
  end

end
