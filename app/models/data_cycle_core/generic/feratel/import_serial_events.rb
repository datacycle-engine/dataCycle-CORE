# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportSerialEvents
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists' => true } }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::Feratel::Processing.process_image(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :image)
            )
            DataCycleCore::Generic::Feratel::Processing.process_serial_event(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :serial_event)
            )
          end
        end
      end
    end
  end
end
