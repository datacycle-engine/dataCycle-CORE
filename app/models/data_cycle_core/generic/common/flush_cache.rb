# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module FlushCache
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.logging_without_mongo(
            utility_object: utility_object,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.process_content(*)
          queued_jobs = Delayed::Jobs.where(queue: 'cache_invalidation')
          items_count = queued_jobs.count
          Rails.cache.clear
          queued_jobs.destroy_all
          items_count
        end
      end
    end
  end
end
