# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module ImportEvent
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists' => true } }.merge(source_filter))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            next if raw_data.dig('localizedData', 'name').blank? # unnamed events are not imported

            DataCycleCore::Generic::Pimcore::Processing.process_place(
              utility_object,
              raw_data.dig('organiser'),
              options.dig(:import, :transformations, :place)
            )

            DataCycleCore::Generic::Pimcore::Processing.process_organization(
              utility_object,
              raw_data.dig('organiser'),
              options.dig(:import, :transformations, :organization)
            )

            DataCycleCore::Generic::Pimcore::Processing.process_event(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :event)
            )
          end
        end
      end
    end
  end
end
