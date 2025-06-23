# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadMarkDeleted
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.mark_deleted_from_data(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          minimum_filter_keys = ["dump.#{locale}", "dump.#{locale}.deleted_at", "dump.#{locale}.archived_at", 'updated_at']
          raise 'Possible wrong source_filter' if source_filter.blank? || source_filter.keys.none? { |k| minimum_filter_keys.exclude?(k) }
          mongo_item.where(source_filter)
        end
      end
    end
  end
end
