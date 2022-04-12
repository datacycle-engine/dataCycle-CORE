# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DestinationOne
      module Processing
        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_poi(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_poi(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_gastro(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_gastro(utility_object.external_source.id),
            default: { template: 'Gastronomischer Betrieb' },
            config: config
          )
        end

        def self.process_hotel(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_hotel(utility_object.external_source.id),
            default: { template: 'Unterkunft' },
            config: config
          )
        end

        def self.process_tour(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_tour(utility_object.external_source.id),
            default: { template: 'Tour' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_image,
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_organizer(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_organizer,
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_content_location(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_content_location,
            default: { template: 'POI' },
            config: config
          )
        end
      end
    end
  end
end
