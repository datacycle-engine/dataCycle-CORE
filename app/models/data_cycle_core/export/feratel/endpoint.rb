# frozen_string_literal: true

module DataCycleCore
  module Export
    module Feratel
      class Endpoint < DataCycleCore::Export::Generic::Endpoint
        def transformations
          DataCycleCore::Export::Feratel::Transformations
        end

        def initialize(**options)
          @pos_code = options.dig(:pos_code)
          @company_code = options.dig(:company_code)
          @endpoint_url = options.dig(:endpoint_url)
        end

        def content_request(transformation:, utility_object:, data:, method: :post, **_options)
          return if data.external_source_id.present? # only manually created

          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          item =
            case data.template_name
            when 'Event'
              'Event'
            when 'POI'
              'Infrastructure'
            end
          url = format(@endpoint_url, { item: item }) || "http://interface.deskline.net/DSI/#{item}.asmx/Import"

          begin
            body = transformations.try(transformation, data, utility_object)

            puts Nokogiri::XML(body, &:noblanks).to_xml(indent: 2)
            puts
            puts

            @output_file.info(Nokogiri::XML(body, &:noblanks).to_xml(indent: 2))

            @response = Faraday.run_request(method, url, URI.encode_www_form('xmlString' => body), { 'Content-Type' => 'application/x-www-form-urlencoded' })

            # puts Nokogiri::XML(@response.body, &:noblanks).to_xml(indent: 2)
            # puts
            # puts

            envelop = Nokogiri::XML(@response.body)
            resp = Nokogiri::XML(envelop.children.first.content)
            resp.remove_namespaces!

            item_hash = resp.xpath("//#{item}").first.to_h

            @output_file.info("#{@response&.env&.dig(:method)&.to_s&.upcase} #{@response&.env&.dig(:url)} #{@response.body}", "#{data&.id} - #{@response&.env&.dig(:status)} #{@response&.env&.dig(:reason_phrase)}")
            @output_file.try(:close)
          rescue Faraday::Error => e
            @output_file.error(e.try(:response)&.dig(:status), "#{data&.id}_#{I18n.locale}", nil, e.try(:response)&.dig(:body))
            @output_file.try(:close)
            raise e
          end
          item_hash
        end
      end
    end
  end
end
