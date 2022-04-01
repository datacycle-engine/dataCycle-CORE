# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Timm4
      module Processing
        def self.process_poi(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Timm4::Transformations.to_poi(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_gastronomy(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Timm4::Transformations.to_gastronomy(utility_object.external_source.id),
            default: { template: 'Gastronomischer Betrieb' },
            config: config
          )
        end

        def self.process_track(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Timm4::Transformations.to_tour(utility_object.external_source.id),
            default: { template: 'Tour' },
            config: config
          )
        end

        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Timm4::Transformations.to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_organizer(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Timm4::Transformations.to_organizer,
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_event_location(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Timm4::Transformations.to_event_location,
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Timm4::Transformations.to_image,
            default: { template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
