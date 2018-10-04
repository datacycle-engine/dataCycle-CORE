# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Processing
        def self.process_lake(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Bergfex::Transformations.bergfex_to_see,
            default: { content_type: DataCycleCore::Place, template: 'See' },
            config: config
          )
        end

        def self.process_ski_resort(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Bergfex::Transformations.bergfex_to_ski_resort,
            default: { content_type: DataCycleCore::Place, template: 'Skigebiet' },
            config: config
          )
        end
      end
    end
  end
end
