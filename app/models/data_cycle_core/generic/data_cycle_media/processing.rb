# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleMedia
      module Processing
        def self.process_image(utility_object, raw_data, config)
          place_template = config&.dig(:place_template) || 'Örtlichkeit'
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::MediaArchive::Transformations.media_archive_to_bild(utility_object.external_source.id, place_template),
            default: { content_type: DataCycleCore::CreativeWork, template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
