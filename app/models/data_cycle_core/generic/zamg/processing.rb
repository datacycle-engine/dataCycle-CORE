# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Zamg
      module Processing
        def self.process_weather(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Zamg::Transformations.to_weather(utility_object.external_source.id),
            default: { content_type: DataCycleCore::Thing, template: 'Wetterstation' },
            config: config
          )
        end
      end
    end
  end
end
