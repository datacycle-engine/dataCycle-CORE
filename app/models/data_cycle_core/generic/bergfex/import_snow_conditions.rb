# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module ImportSnowConditions
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Bergfex - Kategorien',
            method(:load_root_classifications).to_proc,
            ->(_, _, _) { [] },
            ->(_, _, _) { nil },
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, _locale, options)
          source_filter = options.dig(:import, :source_filter)
          mongo_item.where(source_filter)
        end

        def self.extract_data(_options, raw_data)
          {
            external_key: "CATEGORY:#{raw_data['id']}",
            name: raw_data['text']
          }
        end
      end
    end
  end
end
