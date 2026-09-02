# frozen_string_literal: true

# Marks existing Mongo download items as deleted (sets +dump.<locale>.deleted_at+) by loading every
# document that matches +source_filter+ and saving it back individually
# (see DownloadFunctions.mark_deleted_from_data).
#
# This is the per-document variant: it loads and re-saves each matched document one-by-one, so it does
# not scale to large collections. Prefer DownloadBulkMarkDeleted unless you need semantics only this
# variant offers (+delete_all_languages+ or archiving via +archive_from+/+archive_reason+).
#
# The strategy iterates over every configured locale (see +locales+); each pass operates on a single locale
# and, unless +delete_all_languages+ is set, only touches that locale's +dump.<locale>+.
#
# Configuration (keys live under the download_config entry, unless noted as a runtime option):
#   source_type           (required) Mongo collection to scan and mark, and the DC content type.
#   source_filter         (required) MongoDB query selecting the documents to mark deleted. Raises when blank
#                                    (marking without a filter is dangerous) or when it contains only the
#                                    auto-added guard keys. It is auto-augmented so documents that are already
#                                    deleted/archived, or that have no +dump.<locale>+, are skipped.
#   delete_reason         (optional) Stored under +dump.<locale>.delete_reason+.
#   delete_all_languages  (optional, default false) When true, sets +deleted_at+ for every language present in
#                                    the document's +dump+, not only the current locale.
#   archive_from          (optional) Ruby expression (eval'd) returning a Time; documents whose +seen_at+ is
#                                    newer are skipped. With an +archived+ callback the matched documents are
#                                    archived (+archived_at+) instead of deleted.
#   archive_reason        (optional) Stored under +dump.<locale>.archive_reason+ when archiving.
#   iterator_type         (optional) Set to 'aggregate' to iterate via aggregation instead of a plain cursor.
#   max_count / min_count (optional, runtime) Upper / lower bound on the number of processed documents.
#
# NOTE: +external_key_path+ is NOT read by this strategy; documents are selected purely via +source_filter+.
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
