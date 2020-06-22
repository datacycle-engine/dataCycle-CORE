# frozen_string_literal: true

module DataCycleCore
  module Generic
    module VTicket
      module DownloadMarkDeleted
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.mark_deleted_from_data(
            download_object: utility_object,
            iterator: method(:load_contents).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}": { '$exists': true }))
        end
      end
    end
  end
end
