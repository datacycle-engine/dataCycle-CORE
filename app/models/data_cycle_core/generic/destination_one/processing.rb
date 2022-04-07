# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DestinationOne
      module Processing
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

        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DestinationOne::Transformations.to_image,
            default: { template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
