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

        def self.process_person(utility_object, raw_data, config, external_key)
          return if raw_data&.values_at('name', 'givenName', 'familyName')&.compact.blank?

          if raw_data&.dig('worksFor').present?
            DataCycleCore::Generic::MediaArchive::Processing.process_person(
              utility_object,
              raw_data['worksFor'],
              { template: 'Organization' },
              Digest::SHA1.hexdigest(raw_data.dig('worksFor', 'name'))
            )
          end

          template = config&.dig(:template) || 'Person'

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              DataCycleCore::Generic::MediaArchive::Transformations
                .media_archive_to_person(utility_object.external_source.id)
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
