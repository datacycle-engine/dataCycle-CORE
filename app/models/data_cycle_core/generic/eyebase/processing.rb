# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      module Processing
        def self.process_media_asset(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Eyebase::Transformations.eyebase_to_bild(utility_object.external_source.id),
            default: { template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
