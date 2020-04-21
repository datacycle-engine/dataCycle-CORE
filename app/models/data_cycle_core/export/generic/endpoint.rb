# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      class Endpoint
        def transformations
          DataCycleCore::Export::Generic::Transformations
        end

        def initialize(**options)
          @host = format(options.dig(:host), dockerhost: `ip route show`[/default.*/][/\d+\.\d+\.\d+\.\d+/].prepend('http://'))
          @token = options.dig(:token)
        end

        def content_request(method: :post, path:, transformation:, utility_object:, data:)
          @response = Faraday.run_request(method, File.join(@host, path), transformations.try(transformation, utility_object, data), { 'Content-Type' => 'application/json' })
          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          begin
            @response = Faraday.run_request(method, File.join(@host, path), transformations.try(transformation, utility_object, data), { 'Content-Type' => 'application/json' })
            @output_file.info("#{@response&.env&.dig(:method)&.to_s&.upcase} #{@response&.env&.dig(:url)} #{@response.body}", "#{data&.id} - #{@response&.env&.dig(:status)} #{@response&.env&.dig(:reason_phrase)}")
            @output_file.try(:close)
          rescue Faraday::Error => e
            @output_file.error(e.try(:response)&.dig(:status), "#{data&.id}_#{I18n.locale}", nil, e.try(:response)&.dig(:body))
            @output_file.try(:close)
            raise e
          end

          @response
        end
      end
    end
  end
end
