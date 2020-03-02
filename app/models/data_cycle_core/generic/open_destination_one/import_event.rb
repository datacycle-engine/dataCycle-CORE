# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OpenDestinationOne
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
            if raw_data.dig('location').present?
              place_data = DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(raw_data.dig('location'))
              DataCycleCore::Generic::OpenDestinationOne::Processing.process_place(
                utility_object,
                place_data,
                options.dig(:import, :transformations, :place)
              )
            end

            # DataCycleCore::Generic::Pimcore::Processing.process_organization(
            #   utility_object,
            #   raw_data.dig('organiser'),
            #   options.dig(:import, :transformations, :organization)
            # )

            # DataCycleCore::Generic::Pimcore::Processing.process_event(
            #   utility_object,
            #   raw_data,
            #   options.dig(:import, :transformations, :event)
            # )
          end
        end
      end
    end
  end
end
