# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wogehmahin
      module Processing
        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Wogehmahin::Transformations.to_image,
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_poi(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Wogehmahin::Transformations.to_food_establishment(utility_object.external_source.id),
            default: { template: 'Gastronomischer Betrieb' },
            config: config
          )
        end
      end
    end
  end
end
