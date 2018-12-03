# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module Processing
        def self.process_place(utility_object, raw_data, config)
          return if raw_data.nil? || raw_data['contentLocation'].blank?
          raw_place_data = raw_data['contentLocation']
          return if raw_place_data['address'].blank? && (raw_place_data['geo'].blank? || (raw_place_data['geo']['latitude'] == 0.0 && raw_place_data['geo']['longitude'] == 0.0))
          raw_place_data['url'] = raw_data['url']

          template = config&.dig(:template) || 'Örtlichkeit'
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_place_data,
            transformation: DataCycleCore::Generic::MediaArchive::Transformations.media_archive_to_content_location(template),
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end

        def self.process_photographer(utility_object, raw_data, config = {})
          type = raw_data&.dig('photographer', 'type')
          config[:template] = config&.dig("#{type}_template".to_sym) || 'Person'

          process_person(
            utility_object,
            type == 'person' ? raw_data['photographer']&.except('type', 'name') : raw_data['photographer']&.except('type', 'givenName', 'familyName'),
            "Fotograf: #{raw_data['url'].split('/').last}",
            config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          place_template = config&.dig(:place_template) || 'Örtlichkeit'
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::MediaArchive::Transformations.media_archive_to_bild(utility_object.external_source.id, place_template),
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_video(utility_object, raw_data, config)
          place_template = config&.dig(:place_template) || 'Örtlichkeit'
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::MediaArchive::Transformations.media_archive_to_video(utility_object.external_source.id, place_template),
            default: { template: 'Video' },
            config: config
          )
        end

        def self.process_contributor(utility_object, raw_data, config)
          process_person(utility_object, raw_data['contributor'], "Person: #{raw_data['url'].split('/').last}", config)
        end

        def self.process_director(utility_object, raw_data, config)
          process_person(utility_object, raw_data['director'], "Person: #{raw_data['url'].split('/').last}", config)
        end

        def self.process_person(utility_object, raw_data, external_key, config)
          return if raw_data&.values_at('name', 'givenName', 'familyName').blank?
          template = config&.dig(:template) || 'Person'

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
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
