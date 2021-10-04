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

        def self.process_video(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Eyebase::Transformations.to_video(utility_object.external_source.id),
            default: { template: 'Video' },
            config: config
          )
        end

        def self.process_audio(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Eyebase::Transformations.to_audio(utility_object.external_source.id),
            default: { template: 'Audio' },
            config: config
          )
        end

        def self.process_organization(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Eyebase::Transformations.to_organization,
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_content_location(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Eyebase::Transformations.to_place,
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end
      end
    end
  end
end
