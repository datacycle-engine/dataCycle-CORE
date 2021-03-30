# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Download
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options: options.merge(iteration_strategy: :download_all)
          )
        end

        def self.data_id(data)
          data['id']
        end

        def self.data_name(data)
          data['name']
        end
      end
    end
  end
end
