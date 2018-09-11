# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelResort
      module Processing
        def self.process_infrastructure(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelResort::Transformations.feratel_to_infrastructure(utility_object.external_source.id),
            default: { content_type: DataCycleCore::Place, template: 'POI' },
            config: config
          )
        end
      end
    end
  end
end
