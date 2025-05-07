# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkMarkDeletedFromThingHistories
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_mark_deleted(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_contents(download_object:, **)
          sql = <<~SQL.squish
            EXISTS (
              SELECT 1 FROM things
              WHERE things.external_source_id = thing_histories.external_source_id
              AND things.external_key = thing_histories.external_key
            )
          SQL

          DataCycleCore::Thing::History
            .where(external_source_id: download_object.external_source.id)
            .where.not(deleted_at: nil)
            .where.not(deleted_by: nil)
            .where.not(sql)
            .pluck(:external_key)
        end
      end
    end
  end
end
