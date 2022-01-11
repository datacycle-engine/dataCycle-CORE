# frozen_string_literal: true

module DataCycleCore
  module Generic
    module IntermapsIski
      module Processing
        def self.process_ski_region(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::IntermapsIski::Transformations.to_ski_region,
            default: { template: 'Skigebiet' },
            config: config
          )
        end

        def self.process_lift(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::IntermapsIski::Transformations.to_lift(utility_object.external_source.id),
            default: { template: 'Lift' },
            config: config
          )
        end

        def self.process_slope(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::IntermapsIski::Transformations.to_slope(utility_object.external_source.id),
            default: { template: 'Piste' },
            config: config
          )
        end
      end
    end
  end
end
