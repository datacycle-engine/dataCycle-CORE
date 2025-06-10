# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkTouchFromData
        def self.download_content(utility_object:, options:)
          DownloadFunctions.bulk_touch_items(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_contents(options: {}, **)
          data = DownloadDataFromData.load_data_from_mongo(options:, **)

          if options.dig(:download, :data_id_transformation)
            data.each do |s|
              s['id'] =
                DownloadDataFromData.data_id(options.dig(:download, :data_id_transformation), s)
            end
          end

          data.pluck('id')
        end
      end
    end
  end
end
