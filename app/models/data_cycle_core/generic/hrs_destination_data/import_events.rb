# frozen_string_literal: true

module DataCycleCore
  module Generic
    module HrsDestinationData
      module ImportEvents
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options.merge({ iterator_type: :aggregate })
          )
        end

        def self.load_contents(mongo_item, _locale, source_filter)
          # hardcoded locale = de
          mongo_item.collection.aggregate(
            [
              { '$match': { _id: { '$exists': true } }.merge(source_filter) }, # import only not deleted or archived data
              { '$group': { _id: '$dump.de.event.id', dates: { '$addToSet': '$dump.de.date' }, dump: { '$last': '$dump' } } },
              { '$addFields': { 'dump.de.dates': '$dates' } }
            ]
          )
          # db.events.aggregate([
          #   { $match: { _id: { $exists: true } } },
          #   { $group: { _id: '$dump.de.event.id', dates: { $addToSet: '$dump.de.date'}, dump: { $last: '$dump'}}}
          #  ])
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            if raw_data.dig('event', 'venue', 'id').present?
              DataCycleCore::Generic::HrsDestinationData::Processing.process_venue(
                utility_object,
                raw_data.dig('event', 'venue'),
                options.dig(:import, :transformations, :venue)
              )
            end

            if raw_data.dig('event', 'contact', 'id').present?
              DataCycleCore::Generic::HrsDestinationData::Processing.process_contact(
                utility_object,
                raw_data.dig('event', 'contact'),
                options.dig(:import, :transformations, :contact)
              )
            end

            if raw_data.dig('event', 'image', 'id').present? && raw_data.dig('event', 'image', 'thumbnails', 't0', 'url').present?
              DataCycleCore::Generic::HrsDestinationData::Processing.process_image(
                utility_object,
                raw_data.dig('event', 'image'),
                options.dig(:import, :transformations, :image)
              )
            end

            DataCycleCore::Generic::HrsDestinationData::Processing.process_event(
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
