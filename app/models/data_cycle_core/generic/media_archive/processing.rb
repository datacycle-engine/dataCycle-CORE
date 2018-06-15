# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module Processing
        def self.process_place(utility_object, raw_data, config)
          return if raw_data.nil? || (raw_data['address'].blank? && (raw_data['geo'].blank? || (raw_data['geo']['latitude'] == 0.0 && raw_data['geo']['longitude'] == 0.0)))

          template = config.dig(:template) || 'Örtlichkeit'
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data['contentLocation'],
            transformation: DataCycleCore::Generic::OutdoorActive::Transformations.media_archive_to_content_location(template),
            default: { content_type: DataCycleCore::Place, template: 'Örtlichkeit' },
            config: config
          )
        end

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

        def self.process_video(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::MediaArchive::Transformations.media_archive_to_video(utility_object.external_source.id),
            default: { content_type: DataCycleCore::CreativeWork, template: 'Video' },
            config: config
          )
        end

        def self.process_contributor(utility_object, raw_data, config)
          process_person(utility_object, raw_data[:contributor], "Kamera: #{raw_data[:url].split('/').last}", config)
        end

        def self.process_director(utility_object, raw_data, config)
          process_person(utility_object, raw_data[:director], "Regie: #{raw_data[:url].split('/').last}", config)
        end

        def self.process_person(utility_object, raw_data, external_key, config)
          return nil if raw_data.blank?
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Person
          template = config&.dig(:template) || 'Person'

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utlity_object: utility_object,
            class_type: type,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template(type, template),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              DataCycleCore::Generic::MediaArchive::Transformations
                .media_archive_to_person
                .call(raw_data)
            ).merge(
              external_key: external_key
            ).with_indifferent_access
          )
        end
      end
    end
  end
end
