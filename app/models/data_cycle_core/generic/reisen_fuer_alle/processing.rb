# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module Processing
        def self.process_rating(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::ReisenFuerAlle::Transformations.to_rating(utility_object.external_source.id),
            default: { template: 'Zertifizierung' },
            config: config
          )
        end
      end
    end
  end
end
