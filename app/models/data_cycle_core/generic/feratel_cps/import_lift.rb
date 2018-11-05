# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelCps
      module ImportLift
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}": { '$exists' => true }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['type_lift', 'status_lift'].each do |tag_name|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', tag_name).deep_symbolize_keys }
              )
            end

            DataCycleCore::Generic::FeratelCps::Processing.process_lift(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :lift)
            )
          end
        end
      end
    end
  end
end
