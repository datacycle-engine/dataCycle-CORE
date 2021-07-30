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

        def self.process_event_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Pimcore::Transformations.to_event_image,
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_place(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Pimcore::Transformations.to_place,
            default: { template: 'POI' },
            config: config
          )
        end

        def self.process_organization(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data.merge('place_key' => Digest::MD5.hexdigest(DataCycleCore::Generic::Common::DownloadFunctions.bson_to_hash(raw_data).merge('place' => true).to_s)),
            transformation: DataCycleCore::Generic::Pimcore::Transformations.to_organization(utility_object.external_source.id),
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_event(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Pimcore::Transformations.to_event(utility_object.external_source.id),
            default: { template: 'Event' },
            config: config
          )
        end

        def self.process_event_series(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Pimcore::Transformations.to_event_series(utility_object.external_source.id),
            default: { template: 'Event' },
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
