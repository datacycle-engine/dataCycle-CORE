# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadBulkTouchFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.bulk_touch_items(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options:
          )
        end

        def self.credentials?
          false
        end

        def self.load_contents(locale:, source_filter:, options:, **_keyword_args)
          read_type_name = options.dig(:download, :read_type)
          raise ArgumentError, 'missing read_type for loading location ranges' if read_type_name.nil?
          read_type = Mongoid::PersistenceContext.new(
            DataCycleCore::Generic::Collection, collection: read_type_name
          )

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo
              .where(source_filter.merge({ "dump.#{locale}" => { '$ne' => nil } }))
              .to_a
              .pluck('external_id')
          end
        end
      end
    end
  end
end
