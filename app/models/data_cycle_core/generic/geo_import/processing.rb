# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoImport
      module Processing
        def self.process_tour(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::GeoImport::Transformations.to_tour,
            default: { template: 'Tour' },
            config: config
          )
        end
      end
    end
  end
end
