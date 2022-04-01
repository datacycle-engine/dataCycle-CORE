# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      module Endpoint
        class LogFileEndpoint < DataCycleCore::Export::Common::Endpoint::GenericEndpoint
          def initialize(**options)
            @log_file = options.dig(:log_file) || 'log_file_endpoint'
          end

          def log_request(body:, data:, method:)
            output_file = DataCycleCore::Generic::Logger::LogFile.new(@log_file)
            output_file.preparing_phase("#{method} Content")
            output_file.debug(data.name, data.id, body)
            output_file.close if output_file.respond_to?(:close)
          end
        end
      end
    end
  end
end
