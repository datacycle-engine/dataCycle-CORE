# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Hrs
      module Processing
        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Hrs::Transformations.hrs_to_image,
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_room(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Hrs::Transformations.hrs_to_unterkunft(utility_object.external_source.id),
            default: { template: 'Unterkunft' },
            config: config
          )
        end
      end
    end
  end
end
