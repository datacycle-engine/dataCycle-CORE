# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Wogehmahin
      module ImportFoodEstablishments
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, _locale, source_filter)
          mongo_item.where(source_filter).all
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['topics', 'types'].each do |tag_name|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', tag_name).deep_symbolize_keys }
              )
            end

            raw_data.dig('photos').each do |image_data|
              DataCycleCore::Generic::Wogehmahin::Processing.process_image(
                utility_object,
                image_data,
                options.dig(:import, :transformations, :image)
              )
            end
            DataCycleCore::Generic::Wogehmahin::Processing.process_poi(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :food_establishment)
            )
          end
        end
      end
    end
  end
end