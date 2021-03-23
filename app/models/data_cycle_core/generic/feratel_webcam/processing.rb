# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FertalWebcam
      module Processing
        def self.process_lift(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_lift(utility_object.external_source.id),
            default: { template: 'Lift' },
            config: config
          )
        end
      end
    end
  end
end
