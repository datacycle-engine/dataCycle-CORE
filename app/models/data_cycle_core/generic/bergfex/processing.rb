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
      end
    end
  end
end
