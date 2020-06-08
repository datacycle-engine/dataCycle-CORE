# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Xamoom
      module Processing
        def self.process_image(utility_object, raw_data, config)
          return if raw_data&.dig('attributes', 'image').blank?
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Xamoom::Transformations.xamoom_to_image,
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_spot(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Xamoom::Transformations.xamoom_to_poi(utility_object.external_source.id),
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end
      end
    end
  end
end
