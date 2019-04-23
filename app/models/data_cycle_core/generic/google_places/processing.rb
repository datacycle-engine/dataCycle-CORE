# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GooglePlaces
      module Processing
        def self.process_place(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::GooglePlaces::Transformations.google_places_to_poi(utility_object.external_source.id),
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end
      end
    end
  end
end
