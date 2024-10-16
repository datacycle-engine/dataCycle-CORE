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

        def content_request(utility_object:, data:)
          method = utility_object.http_method
          path = utility_object.path(data)
          transformation = utility_object.transformation
          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          begin
            @response = Faraday.run_request(
              method,
              File.join(@host, path),
              transformation.is_a?(Proc) ? transformation.call(utility_object, data) : transformations.try(transformation, utility_object, data),
              { 'Content-Type' => 'application/json' }
            ) do |req|
              req.params['token'] = @token if @token_type == 'url'

              utility_object.external_system.credentials(:export)&.dig('faraday_options')&.to_h&.each do |key, value|
                req.options[key] = value
              end
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
      end
    end
  end
end
