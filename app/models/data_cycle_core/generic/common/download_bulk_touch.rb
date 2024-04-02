# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkTouch
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_touch_items(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:
          )
        end

        def self.load_contents(mongo_item, locale, source_filter, external_keys)
          mongo_item.where(
            I18n.with_locale(locale) { source_filter.with_evaluated_values }
              .merge({
                "dump.#{locale}" => { '$exists' => true },
                'external_id' => { '$in' => external_keys }
              })
          )
        end
      end
    end
  end
end
