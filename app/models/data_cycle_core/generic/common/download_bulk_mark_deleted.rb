# frozen_string_literal: true

# Marks existing Mongo download items as deleted using a single bulk update. It runs in two steps:
#   1. loads only the ids of the documents matching +source_filter+ via an aggregation pipeline
#      (DownloadDataFromData.load_ids_from_mongo), then
#   2. issues one aggregation-pipeline +update_many+ that sets +dump.<locale>.deleted_at+ (plus
#      +last_seen_before_delete+, copied from the document's own +seen_at+, and, when given,
#      +dump.<locale>.delete_reason+) on every document whose +external_id+ is in that id list.
#
# This is the scalable counterpart to DownloadMarkDeleted: it neither loads nor re-saves documents one-by-one.
# It always forces +:full+ mode (so the incremental +updated_at+ filter is skipped) and iterates over every
# configured locale (see +locales+), marking one locale per pass.
#
# Configuration (keys live under the download_config entry):
#   source_type            (required) Mongo collection to scan and update; also the default for +read_type+.
#   source_filter          (required) MongoDB query selecting the documents to mark deleted. It is auto-augmented
#                                     so documents that are already deleted/archived, or that have no
#                                     +dump.<locale>+, are skipped. There is NO blank-guard, so an empty filter
#                                     would match (and delete) every remaining document — always provide one.
#   delete_reason          (optional) Stored under +dump.<locale>.delete_reason+.
#   data_id_path           (optional, default 'id') Path within +dump.<locale>+ to the value used as the key.
#                                     The plucked value is matched against each document's +external_id+
#                                     (e.g. 'uuid' when the external id lives at +dump.<locale>.uuid+).
#   data_id_transformation (optional) Hash ({ module:, method: }) or digest name used to derive the key instead
#                                     of a plain pluck of +data_id_path+.
#   read_type              (optional, default = source_type) Mongo collection read when loading the ids.
#
# NOTE: +external_key_path+ is NOT read by this strategy (that key belongs to the import/delete strategies) —
#       use +data_id_path+ instead. +delete_all_languages+, +archive_from+/+archive_reason+ and
#       +max_count+/+min_count+ are NOT supported here; use DownloadMarkDeleted for those.
module DataCycleCore
  module Generic
    module Common
      module DownloadBulkMarkDeleted
        def self.download_content(utility_object:, options:)
          utility_object.mode = :full
          options[:mode] = 'full'

          DownloadFunctions.bulk_mark_deleted(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_contents(options:, **)
          opts = options
          opts = opts.deep_merge(download: { read_type: opts.dig(:download, :source_type) }) if opts.dig(:download, :read_type).blank?

          DownloadDataFromData.load_ids_from_mongo(options: opts, **)
        end
      end
    end
  end
end
