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
          mongo_item.where(source_filter.merge("dump.#{locale}": { '$exists' => true }, "dump.#{locale}.contentType": 'Video'))
        end

        def self.process_content(raw_data, locale)
          I18n.with_locale(locale) do
            ['tags_videos', 'types_of_use_videos', 'audiences_videos'].each do |tag_name|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', tag_name).deep_symbolize_keys }
              )
            end

            DataCycleCore::Generic::MediaArchive::Processing.process_place(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
            DataCycleCore::Generic::MediaArchive::Processing.process_director(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :director)
            )
            DataCycleCore::Generic::MediaArchive::Processing.process_contributor(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :contributor)
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
