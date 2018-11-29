# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      class Endpoint
        def initialize(**options)
          # TODO: validate credentials?
          @log_file = options.dig(:log_file)
        end

        def log_request(body:, data:)
          output_file = DataCycleCore::Generic::Logger::LogFile.new(@log_file)
          output_file.preparing_phase('Update Content')
          output_file.debug(data.name, data.id, body)
          output_file.close if output_file.respond_to?(:close)
        end
      end
    end
  end
end
