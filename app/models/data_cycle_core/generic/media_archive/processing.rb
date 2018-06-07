# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module Processing
        def process_place(raw_data, config)
          return if raw_data.nil? || (raw_data['address'].blank? && (raw_data['geo'].blank? || (raw_data['geo']['latitude'] == 0.0 && raw_data['geo']['longitude'] == 0.0)))

          type = config.dig('content_type').constantize || DataCycleCore::Place
          template = config.dig(:template) || 'Örtlichkeit'
          default_values = {}
          default_values = load_default_values(config.dig(:default_values)) if config.dig(:default_values).present?

          create_or_update_content(
            type,
            load_template(type, template),
            default_values.merge(
              DataCycleCore::Generic::MediaArchive::Transformations
                .media_archive_to_content_location(template)
                .call(raw_data['contentLocation'])
            ).with_indifferent_access
          )
        end

        def process_image(raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::CreativeWork
          template = config&.dig(:template) || 'Bild'
          place_template = config&.dig(:place_template) || 'Örtlichkeit'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::MediaArchive::Transformations
                .media_archive_to_bild(external_source.id, place_template)
                .call(raw_data)
            ).with_indifferent_access
          )
        end

        def process_video(raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::CreativeWork
          template = config&.dig(:template) || 'Video'
          place_template = config.dig(:place_template) || 'Örtlichkeit'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
              config,
              DataCycleCore::Generic::MediaArchive::Transformations
                .media_archive_to_bild(external_source.id, place_template)
                .call(raw_data)
            ).with_indifferent_access
          )
        end

        def process_contributor(raw_data, config)
          process_person(raw_data[:contributor], "Kamera: #{raw_data[:url].split('/').last}", config)
        end

        def process_director(raw_data, config)
          process_person(raw_data[:director], "Regie: #{raw_data[:url].split('/').last}", config)
        end

        private

        def process_person(raw_data, external_key, config)
          return nil if raw_data.blank?
          type = config&.dig(:content_type)&.constantize || DataCycleCore::Person
          template = config&.dig(:template) || 'Person'

          create_or_update_content(
            type,
            load_template(type, template),
            merge_default_values(
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
