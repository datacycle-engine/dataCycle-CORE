# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gem2go
      module Processing
        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gem2go::Transformations.to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_content_location(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gem2go::Transformations.to_content_location,
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_organizer(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gem2go::Transformations.to_organizer,
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gem2go::Transformations.to_image,
            default: { template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
