# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module Processing
        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Pimcore::Transformations.pimcore_to_image(config.dig(:content_url_prefix)),
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_infrastructure(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Pimcore::Transformations.pimcore_to_poi(utility_object.external_source.id),
            default: { template: 'POI' },
            config: config
          )
        end
      end
    end
  end
end