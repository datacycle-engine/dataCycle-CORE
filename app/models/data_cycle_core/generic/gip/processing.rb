# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gip
      module Processing
        def self.process_section(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gip::Transformations.to_section,
            default: { template: 'Teilstrecke' },
            config: config
          )
        end
      end
    end
  end
end
