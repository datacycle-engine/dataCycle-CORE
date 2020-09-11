# frozen_string_literal: true

module DataCycleCore
  module Export
    module Toursprung
      class Endpoint < DataCycleCore::Export::Generic::Endpoint
        def transformations
          DataCycleCore::Export::Toursprung::Transformations
        end

        def initialize(**options)
          @token = options.dig(:token)
          @username = options.dig(:username)
          @password = options.dig(:password)
          @host = options.dig(:host)
        end

        def content_request(method: :post, path:, transformation:, utility_object:, data:)
          body = transformations.try(transformation, utility_object, data)
          url = File.join(@host, path)
          time_url = File.join(@host, 'rest', 'time')

          time = Faraday.get(time_url)&.body
          body[:api_key] = @username
          body[:token] = Digest::MD5.hexdigest(@token + @password + time)

          @output_file = DataCycleCore::Generic::Logger::LogFile.new("#{utility_object.external_system.name.underscore_blanks}_webhook")

          begin
            @response = Faraday.run_request(method, url, URI.encode_www_form(body), { 'Content-Type' => 'application/x-www-form-urlencoded' })
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
