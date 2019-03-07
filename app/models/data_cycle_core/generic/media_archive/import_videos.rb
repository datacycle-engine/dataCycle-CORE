# frozen_string_literal: true

module DataCycleCore
  module Generic
    module MediaArchive
      module ImportVideos
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}": { '$exists' => true }, "dump.#{locale}.contentType": 'Video'))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale('de') do
            DataCycleCore::Generic::MediaArchive::Processing.process_person(
              utility_object,
              raw_data['contributor'],
              options.dig(:import, :transformations, :contributor),
              "MedienArchive - Person - #{raw_data.dig('contributor', 'id')}"
            )

            DataCycleCore::Generic::MediaArchive::Processing.process_person(
              utility_object,
              raw_data['director'],
              options.dig(:import, :transformations, :director),
              "MedienArchive - Person - #{raw_data.dig('director', 'id')}"
            )

            DataCycleCore::Generic::MediaArchive::Processing.process_person(
              utility_object,
              raw_data['copyrightPerson'],
              options.dig(:import, :transformations, :copyright_person) || { template: 'Person' },
              "MedienArchive - CopyrightHolder - #{raw_data.dig('copyrightPerson', 'id')}"
            )

            DataCycleCore::Generic::MediaArchive::Processing.process_person(
              utility_object,
              raw_data['copyrightOrganization'],
              options.dig(:import, :transformations, :copyright_organization) || { template: 'Organization' },
              "MedienArchive - CopyrightHolder - #{raw_data.dig('copyrightOrganization', 'id')}"
            )
          end

          I18n.with_locale(locale) do
            ['tags_videos', 'types_of_use_videos', 'audiences_videos', 'suggested_audiences_videos', 'file_format_videos'].each do |tag_name|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', tag_name)&.deep_symbolize_keys }
              )
            end
            DataCycleCore::Generic::MediaArchive::Processing.process_place(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
            DataCycleCore::Generic::MediaArchive::Processing.process_video(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :video)
            )
          end
        end
      end
    end
  end
end
