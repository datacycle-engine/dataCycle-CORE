# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Processing
        def self.process_things(utility_object, raw_data, template, config)
          item_template = get_template(raw_data)
          linked_key_translation = {}
          raw_data.dig('included')&.each do |included_item|
            attribute_name = included_item.dig('attribute_name')
            next if attribute_name.blank?
            next unless item_template.property_names.include?(attribute_name)
            linked_key_translation[included_item.dig('attribute_name')] ||= {}
            locale = included_item.except('included', 'attribute_name').keys.first
            found_key = DataCycleCore::Generic::Common::Functions.find_thing_ids(external_system_id: utility_object.external_source.id, external_key: included_item[locale]['id'], content_type: DataCycleCore::Thing, limit: 1)
            linked_key_translation[attribute_name][included_item[locale]['id']] = found_key.first
            if found_key.blank? || found_key.first == included_item[locale]['id']
              new_item = DataCycleCore::Generic::DcSync::Processing.process_things(
                utility_object,
                included_item,
                get_template(included_item).template_name,
                utility_object.external_source.import_config.dig(:things, :transformations, :thing)
              )
              linked_key_translation[attribute_name][included_item[locale]['id']] = new_item.id
            end
          end
          processed_thing = nil
          raw_data.except('included', 'attribute_name', 'include_translation').each_key do |locale|
            I18n.with_locale(locale) do
              processed_thing = DataCycleCore::Generic::Common::ImportFunctions.process_step(
                utility_object: utility_object,
                raw_data: raw_data[locale].except('included').merge({ 'include_translation' => linked_key_translation }),
                transformation: DataCycleCore::Generic::DcSync::Transformations.to_thing(utility_object.external_source.id),
                default: { template: template },
                config: config
              )
            end
          end
          processed_thing
        end

        def self.get_template(data)
          locale = data.keys.except(['included', 'attribute_name']).first
          DataCycleCore::Thing.find_by(template_name: data.dig(locale, 'template_name'), template: true)
        end
      end
    end
  end
end
