# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkMarkDeleted
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_mark_deleted(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_contents(options:, **)
          opts = options
          opts = opts.deep_merge(download: { read_type: opts.dig(:download, :source_type) }) if opts.dig(:download, :read_type).blank?

          DataCycleCore::Generic::Common::DownloadDataFromData.load_data_from_mongo(options: opts, **).pluck('id')
        end
      end
    end
  end
end
