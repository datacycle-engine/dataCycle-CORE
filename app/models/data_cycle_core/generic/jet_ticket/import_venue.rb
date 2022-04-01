# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      module ImportVenue
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, _locale, source_filter)
          mongo_item.where(source_filter).all
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::JetTicket::Processing.process_venue(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
          end
        end
      end
    end
  end
end
