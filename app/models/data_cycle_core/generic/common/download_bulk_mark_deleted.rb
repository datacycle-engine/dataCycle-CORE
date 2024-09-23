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

        def self.load_contents(locale:, source_filter:, options:, download_object:, **_keyword_args)
          read_type = options.dig(:download, :read_type)&.then do |rt|
            Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection2, collection: rt)
          end || download_object.source_type

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.where(source_filter.merge({ "dump.#{locale}" => { '$ne' => nil } }))
              .to_a
              .pluck('external_id')
          end
        end
      end
    end
  end
end
