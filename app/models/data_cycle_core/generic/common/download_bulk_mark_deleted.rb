# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkMarkDeleted
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_mark_deleted(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:
          )
        end

        def self.credentials?
          false
        end

        def self.load_contents(**)
          DataCycleCore::Generic::Common::DownloadDataFromData.load_data_from_mongo(**).pluck('id')
        end
      end
    end
  end
end
