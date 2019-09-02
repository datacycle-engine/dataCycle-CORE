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

        def self.load_contents(mongo_item, _locale, _source_filter)
          # mongo_item.where(source_filter).all
          mongo_item.collection.aggregate(
            [
              { '$match': { _id: { '$exists': true } } },
              { '$group': { _id: '$dump.de.event.id', dates: { '$addToSet': '$dump.de.date' }, dump: { '$first': '$dump' } } },
              { '$addFields': { 'dump.de.dates': '$dates' } }
            ]
          )
          # db.events.aggregate([
          #   { $match: { _id: { $exists: true } } },
          #   { $group: { _id: '$dump.de.event.id', dates: { $addToSet: '$dump.de.date'}, dump: { $first: '$dump'}}}
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
