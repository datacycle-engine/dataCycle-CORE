# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module FlushCache
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.logging_without_mongo(
            utility_object:,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        def self.process_content(*)
          Rails.cache.clear
        end
      end
    end
  end
end
