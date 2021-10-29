# frozen_string_literal: true

module DataCycleCore
  module Generic
    module HrsDestinationData
      module Processing
        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::HrsDestinationData::Transformations.hrs_to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::HrsDestinationData::Transformations.hrs_to_image,
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_venue(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::HrsDestinationData::Transformations.hrs_to_place,
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_contact(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::HrsDestinationData::Transformations.hrs_to_organization,
            default: { template: 'Organization' },
            config: config
          )
        end
      end
    end
  end
end
