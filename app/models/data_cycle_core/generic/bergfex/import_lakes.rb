# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module ImportLakes
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.merge("dump.#{locale}": { '$exists' => true }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::Bergfex::Processing.process_lake(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :lake)
            )
          end
        end
      end
    end
  end
end