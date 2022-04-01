# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelCps
      module Processing
        def self.process_infrastructure(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelCps::Transformations.feratel_to_infrastructure(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_slope(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelCps::Transformations.feratel_to_slope(utility_object.external_source.id),
            default: { template: 'Piste' },
            config: config
          )
        end

        def self.process_lift(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelCps::Transformations.feratel_to_lift(utility_object.external_source.id),
            default: { template: 'Lift' },
            config: config
          )
        end
      end
    end
  end
end
