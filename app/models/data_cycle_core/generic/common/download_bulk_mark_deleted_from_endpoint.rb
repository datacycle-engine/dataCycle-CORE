# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkMarkDeletedFromEndpoint
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_mark_deleted(
            download_object: utility_object,
            options:
          )
        end
      end
    end
  end
end
