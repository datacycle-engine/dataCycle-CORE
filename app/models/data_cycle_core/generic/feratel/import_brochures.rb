# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportBrochures
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists': true } }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            variation_languages = Array.wrap(raw_data.dig('Variations', 'Variation')).map { |i| i.dig('Details', 'Language', 'text') }
            next unless variation_languages.include?(locale.to_s)
            ['feratel_owners'].each do |name_tag|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', name_tag).deep_symbolize_keys }
              )
            end

            DataCycleCore::Generic::Feratel::Processing.process_image(
              utility_object,
              raw_data,
              options&.dig(:import, :transformations, :image)
            )

            Array.wrap(raw_data.dig('Variations', 'Variation')).each do |image_data|
              DataCycleCore::Generic::Feratel::Processing.process_image(
                utility_object,
                image_data,
                options&.dig(:import, :transformations, :image)
              )
            end

            DataCycleCore::Generic::Feratel::Processing.process_brochure(
              utility_object,
              raw_data,
              options&.dig(:import, :transformations, :brochure)
            )
          end
        end
      end
    end
  end
end
