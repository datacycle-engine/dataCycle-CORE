# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      module ImportEvents
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options.merge({ iterator_type: :aggregate }) # switch to aggregation
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.collection.aggregate(
            [
              {
                '$match': {
                  "dump.#{locale}": { '$exists': true }
                }.merge(source_filter.with_evaluated_values)
              }, {
                '$group': {
                  _id: { '$concat': ["$dump.#{locale}.EventSetID", ' - ', "$dump.#{locale}.Name1"] },
                  'dates': { '$addToSet': "$dump.#{locale}.DateTime" },
                  'dump': { '$first': '$dump' }
                }
              }, {
                '$addFields': {
                  "dump.#{locale}.dates": '$dates'
                }
              }
            ]
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            if raw_data.dig('EventManager').present?
              DataCycleCore::Generic::JetTicket::Processing.process_event_manager(
                utility_object,
                raw_data.dig('EventManager'),
                options.dig(:import, :transformations, :organizer)
              )
            end
            if raw_data.dig('Venue').present?
              DataCycleCore::Generic::JetTicket::Processing.process_venue(
                utility_object,
                raw_data.dig('Venue'),
                options.dig(:import, :transformations, :place)
              )
            end
            DataCycleCore::Generic::JetTicket::Processing.process_event(
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
