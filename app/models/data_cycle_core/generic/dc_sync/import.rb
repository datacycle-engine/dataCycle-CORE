# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Import
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({
            "dump.#{locale}": { '$exists' => true },
            "dump.#{locale}.deleted_at": { '$exists' => false }
          }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, _options:)
          I18n.with_locale(locale) do
            raw_data.dig('included').each do |included_linked|
              DataCycleCore::Generic::Feratel::Processing.process_things(
                utility_object,
                included_linked,
                raw_data.dig('template_name')
              )
            end
            DataCycleCore::Generic::Feratel::Processing.process_things(
              utility_object,
              raw_data,
              raw_data.dig('template_name')
            )
          end
        end
      end
    end
  end
end
