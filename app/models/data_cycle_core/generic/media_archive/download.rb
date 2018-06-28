# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module Download
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: ->(data) { data['url'] },
            data_name: ->(data) { data['headline'] },
            options: options.merge(iteration_strategy: :download_parallel)
          )
        end
      end
    end
  end
end
