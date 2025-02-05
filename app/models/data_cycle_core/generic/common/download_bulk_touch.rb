# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkTouch
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_touch_items(
            download_object: utility_object,
            options:
          )
        end
      end
    end
  end
end
