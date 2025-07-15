# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      class Endpoint
        def transformations
          DataCycleCore::Export::Generic::Transformations
        end

        def initialize(**options)
          @host = options[:host]
          @token = options[:token]
          @token_type = options[:token_type] || 'body'
        end

        def content_request(utility_object:, data:)
          method = utility_object.http_method
          path = utility_object.transformed_path(data)
          ess = data.try(:external_system_sync_by_system, external_system: utility_object.external_system)
          transformation = utility_object.transformation
          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          begin
            if transformation.is_a?(Hash) && transformation.key?(:module) && transformation.key?(:method)
              transformed_data = transformation[:module].send(transformation[:method], utility_object, data)
            elsif transformation.is_a?(Proc)
              transformed_data = transformation.call(utility_object, data)
            else
              transformed_data = transformations.try(transformation, utility_object, data)
            end

            exported_data = transformed_data.is_a?(::Hash) ? transformed_data : JSON.parse(transformed_data) rescue nil # rubocop:disable Style/RescueModifier
            ess&.update(exported_data:)

            @response = Faraday.run_request(
              method,
              File.join(@host, path),
              transformed_data,
              { 'Content-Type' => 'application/json' }.merge(utility_object.external_system.credentials(:export)&.dig('additional_headers') || {})
            ) do |req|
              req.params['token'] = @token if @token_type == 'url'

              if @token_type == 'http_headers' && @token.is_a?(Hash)
                @token.each do |k, v|
                  req.headers[k] = v
                end
              elsif @token_type == 'x_api_key'
                req.headers['X-API-KEY'] = @token
              end

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
