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
          @token_type = options.fetch(:token_type, 'body')
        end

        def content_request(method: :post, path:, transformation:, utility_object:, data:)
          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          begin
            @response = Faraday.run_request(method, File.join(@host, path), transformations.try(transformation, utility_object, data), { 'Content-Type' => 'application/json' }) do |req|
              req.params['token'] = @token if @token_type == 'url'
            end
            @output_file.info("#{@response&.env&.dig(:method)&.to_s&.upcase} #{@response&.env&.dig(:url)} #{@response.body}", "#{data&.id} - #{@response&.env&.dig(:status)} #{@response&.env&.dig(:reason_phrase)}")
            @output_file.try(:close)
          rescue Faraday::Error => e
            @output_file.error(e.try(:response)&.dig(:status), "#{data&.id}_#{I18n.locale}", nil, e.try(:response)&.dig(:body))
            @output_file.try(:close)
            raise e
          end

          @response
        end

        def path_transformation(data, external_system, path_type)
          format(external_system.config.dig('export_config', path_type.to_s, 'path') || external_system.config.dig('export_config', 'path') || path_type.to_s, id: data&.id)
        end
      end
    end
  end
end
