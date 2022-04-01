# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleTypo3
      module DownloadMarkDeleted
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.mark_deleted(
            download_object: utility_object,
            data_id: method(:data_id).to_proc,
            options: options
          )
        end

        def self.data_id(data)
          data['uid']
        end
      end
    end
  end
end
