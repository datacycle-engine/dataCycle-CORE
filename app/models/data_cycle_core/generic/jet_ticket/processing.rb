# frozen_string_literal: true

module DataCycleCore
  module Generic
    module JetTicket
      module Processing
        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::JetTicket::Transformations.to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_event_series(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::JetTicket::Transformations.to_event_series(utility_object.external_source.id),
            default: { template: 'Eventserie' },
            config: config
          )
        end

        def self.process_event_manager(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::JetTicket::Transformations.to_organizer(utility_object.external_source.id),
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_venue(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::JetTicket::Transformations.to_place(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end
      end
    end
  end
end
