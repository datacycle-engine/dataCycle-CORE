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

        def content_request(transformation:, path:, utility_object:, data:, method: :post)
          return if data.external_source_id.present? # only manually created
          body = transformations.try(transformation, data, utility_object)

          # puts Nokogiri::XML(body, &:noblanks).to_xml(indent: 2)
          # puts
          # puts

          url = @endpoint_url || 'http://interface.deskline.net/'
          url += path
          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          begin
            @output_file.info(Nokogiri::XML(body, &:noblanks).to_xml(indent: 2))

            @response = Faraday.run_request(method, url, URI.encode_www_form('xmlString' => body), { 'Content-Type' => 'application/x-www-form-urlencoded' })

            # puts Nokogiri::XML(@response.body, &:noblanks).to_xml(indent: 2)
            # puts
            # puts

            @output_file.info("#{@response&.env&.dig(:method)&.to_s&.upcase} #{@response&.env&.dig(:url)} #{@response.body}", "#{data&.id} - #{@response&.env&.dig(:status)} #{@response&.env&.dig(:reason_phrase)}")
            @output_file.try(:close)
          rescue Faraday::Error => e
            @output_file.error(e.try(:response)&.dig(:status), "#{data&.id}_#{I18n.locale}", nil, e.try(:response)&.dig(:body))
            @output_file.try(:close)
            raise e
          end
          @response # return last response
        end
      end
    end
  end
end
