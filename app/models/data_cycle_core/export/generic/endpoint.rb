# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      class Endpoint
        def transformations
          DataCycleCore::Export::Generic::Transformations
        end

        def initialize(**options)
          @host = options.dig(:host)
          @token = options.dig(:token)
          @token_type = options.dig(:token_type) || 'body'
        end

        def content_request(path:, transformation:, utility_object:, data:, method: :post)
          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          begin
            @response = Faraday.run_request(
              method,
              File.join(@host, path),
              transformation.is_a?(Proc) ? transformation.call(utility_object, data) : transformations.try(transformation, utility_object, data),
              { 'Content-Type' => 'application/json' }
            ) do |req|
              req.params['token'] = @token if @token_type == 'url'
            end

            @output_file.info("#{@response&.env&.dig(:method)&.to_s&.upcase} #{@response&.env&.dig(:url)} #{DataCycleCore::NormalizeService.normalize_encoding(@response.body)}", "#{data&.id} - #{@response&.env&.dig(:status)} #{@response&.env&.dig(:reason_phrase)}")
            @output_file.try(:close)
          rescue Faraday::Error => e
            @output_file.error(e.try(:response)&.dig(:status), "#{data&.id}_#{I18n.locale}", nil, e.message)
            @output_file.try(:close)
            raise DataCycleCore::Error::WebhookError, e
          end

          @response
        end

        def path_transformation(data, external_system, path_type, type = '', path = nil)
          format(path.presence || external_system.config.dig('export_config', path_type.to_s, 'path') || external_system.config.dig('export_config', 'path') || path_type.to_s, id: data&.id, type: type)
        end
      end
    end
  end
end
