# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Amtangee
      module Processing
        def self.process_thing(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Amtangee::Transformations.to_thing,
            default: { template: 'POI' },
            config: config
          )
        end
      end
    end
  end
end
