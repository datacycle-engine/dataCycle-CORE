# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module ImportPlaces
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.merge("dump.#{locale}.frontendtype" => 'poi'))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::Common::ImportTags.process_content(
              utility_object: utility_object,
              raw_data: raw_data,
              locale: locale,
              options: { import: utility_object.external_source.config.dig('import_config', 'source_places').deep_symbolize_keys }
            )

            DataCycleCore::Generic::Common::ImportTags.process_content(
              utility_object: utility_object,
              raw_data: raw_data,
              locale: locale,
              options: { import: utility_object.external_source.config.dig('import_config', 'frontendtype_places').deep_symbolize_keys }
            )

            DataCycleCore::Generic::Common::ImportTags.process_content(
              utility_object: utility_object,
              raw_data: raw_data,
              locale: locale,
              options: { import: utility_object.external_source.config.dig('import_config', 'tag_places').deep_symbolize_keys }
            )

            DataCycleCore::Generic::OutdoorActive::Processing.process_image(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :image)
            )
            DataCycleCore::Generic::OutdoorActive::Processing.process_place(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
          end
        end
      end
    end
  end
end
