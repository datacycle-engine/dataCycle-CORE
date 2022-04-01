# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wikidata
      module Processing
        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Wikidata::Transformations.wikimedia_to_image(utility_object.external_source.id),
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_poi(utility_object, raw_data, config)
          return if raw_data.dig('itemLabel', 'xml:lang').blank? # reject items without labels in either de, or en.
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Wikidata::Transformations.wikidata_to_poi(utility_object.external_source.id),
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end
      end
    end
  end
end
