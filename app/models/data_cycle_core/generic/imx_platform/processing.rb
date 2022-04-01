# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ImxPlatform
      module Processing
        def self.process_poi(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::ImxPlatform::Transformations.to_poi(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::ImxPlatform::Transformations.to_image(utility_object.external_source.id),
            default: { template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
