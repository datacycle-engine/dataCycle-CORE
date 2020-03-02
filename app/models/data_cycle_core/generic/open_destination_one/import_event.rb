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

            raw_data.dig('image').each do |image_data|
              DataCycleCore::Generic::OpenDestinationOne::Processing.process_image(
                utility_object,
                image_data,
                options.dig(:import, :transformations, :image)
              )
            end

            if raw_data.dig('organizer').present?
              organizer_data = DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(raw_data.dig('organizer'))
              DataCycleCore::Generic::OpenDestinationOne::Processing.process_organizer(
                utility_object,
                organizer_data,
                options.dig(:import, :transformations, :organization)
              )
            end

            DataCycleCore::Generic::OpenDestinationOne::Processing.process_event(
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
