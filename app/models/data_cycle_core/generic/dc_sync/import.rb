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
          item_template = get_template(raw_data)
          linked_key_translation = {}
          raw_data.dig('included').each do |included_item|
            attribute_name = included_item.dig('attribute_name')
            next if attribute_name.blank?
            next unless item_template.property_names.include?(attribute_name)
            linked_key_translation[included_item.dig('attribute_name')] = {}
            new_item = DataCycleCore::Generic::DcSync::Processing.process_things(
              utility_object,
              included_item,
              get_template(included_item).template_name,
              options.dig(:import, :transformations, :thing)
            )
            linked_key_translation[attribute_name][new_item.external_key] = new_item.id
          end

          DataCycleCore::Generic::DcSync::Processing.process_things(
            utility_object,
            raw_data.except('included').merge('include_translation' => linked_key_translation),
            get_template(raw_data).template_name,
            options.dig(:import, :transformations, :thing)
          )
        end

        def self.get_template(data)
          locale = data.keys.except(['included', 'attribute_name']).first
          DataCycleCore::Thing.find_by(template_name: data.dig(locale, 'template_name'), template: true)
        end
      end
    end
  end
end
