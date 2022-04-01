# frozen_string_literal: true

module DataCycleCore
  module Generic
    module VTicket
      module ImportEvents
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}": { '$exists': true }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['categories', 'tags'].each do |tag_name|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', tag_name).deep_symbolize_keys }
              )
            end
            DataCycleCore::Generic::VTicket::Processing.process_place(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
            DataCycleCore::Generic::VTicket::Processing.process_image(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :image)
            )
            DataCycleCore::Generic::VTicket::Processing.process_event(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :event)
            )
          end
        end
      end
    end
  end
end
