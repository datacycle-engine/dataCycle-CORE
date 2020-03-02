# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OpenDestinationOne
      module Processing
        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::OpenDestinationOne::Transformations.to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_place(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::OpenDestinationOne::Transformations.to_place,
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end
      end
    end
  end
end
