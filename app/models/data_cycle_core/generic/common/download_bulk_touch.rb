# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkTouch
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_touch_items(
            download_object: utility_object,
            options:,
            data_id: method(:data_id).to_proc.curry[options]
          )
        end

        def self.data_id(options, item)
          return item unless item.is_a?(Hash)

          external_key_path = options.dig(:download, :external_key_path)
          external_key_prefix = options.dig(:download, :external_key_prefix) || ''
          return if external_key_path.blank?

          key_parts = external_key_path.split('.')
          value = item.dig(*key_parts)

          "#{external_key_prefix}#{value}"
        end
      end
    end
  end
end
