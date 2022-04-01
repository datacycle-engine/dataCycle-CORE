# frozen_string_literal: true

module DataCycleCore
  module Export
    module TextFile
      class Endpoint < DataCycleCore::Export::Common::Endpoint::LogFileEndpoint
        def refresh_request(options = {})
          output_file = DataCycleCore::Generic::Logger::LogFile.new(@log_file)
          output_file.preparing_phase('refresh Content')
          output_file.debug('refresh', 'id goes here', "wuhu #{options}")
          output_file.close if output_file.respond_to?(:close)
        end
      end
    end
  end
end
