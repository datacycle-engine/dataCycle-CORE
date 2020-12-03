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
            options: options.merge(iteration_strategy: :import_all)
          )
        end

        def self.load_contents(mongo_item, _locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values)
        end

        def self.process_content(utility_object:, raw_data:, options:, **_unused)
          item_template = DataCycleCore::Thing.find_by(template_name: raw_data.dig(raw_data.keys.first, 'template_name'), template: true)
          # raw_data.dig('included').each do |included_item|
          #   next unless item_template.property_names.include?(included_item.dig('attribute_name'))
          #   DataCycleCore::Generic::DcSync::Processing.process_things(
          #     utility_object,
          #     included_item,
          #     raw_data.dig('template_name'),
          #     options.dig(:import, :transformations, :thing)
          #   )
          # end
          DataCycleCore::Generic::DcSync::Processing.process_things(
            utility_object,
            raw_data.except('included'),
            item_template.template_name,
            options.dig(:import, :transformations, :thing)
          )
        end
      end
    end
  end
end
