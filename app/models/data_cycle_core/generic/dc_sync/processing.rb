# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Processing
        def self.process_things(utility_object, raw_data, template, config)
          item_template = get_template(raw_data)
          linked_key_translation = process_included_items(utility_object, item_template, raw_data.dig('included'))
          processed_thing = nil
          raw_data.except('included', 'attribute_name', 'include_translation').each_key do |locale|
            I18n.with_locale(locale) do
              data_correct_linked = transform_linked_keys(raw_data[locale].except('included').merge({ 'include_translation' => linked_key_translation }))
              data_correct_embedded = transform_embedded(data_correct_linked, utility_object)

              processed_thing = DataCycleCore::Generic::Common::ImportFunctions.process_step(
                utility_object: utility_object,
                raw_data: data_correct_embedded,
                transformation: DataCycleCore::Generic::DcSync::Transformations.to_thing(utility_object.external_source.id),
                default: { template: template },
                config: config
              )
            end
          end
          processed_thing
        end

        def self.process_included_items(utility_object, parent_template, included_items)
          linked_key_translation = {}
          included_items&.each do |included_item|
            attribute_name = included_item.dig('attribute_name')
            next if attribute_name.blank?
            next unless parent_template.property_names.include?(attribute_name)
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
          linked_key_translation
        end

        def self.transform_linked_keys(data)
          translated_properties = data['include_translation']
          translated_properties&.each_key do |property_name|
            data[property_name] = Array.wrap(data[property_name])
              .map { |item| translated_properties[property_name][item] }
              .compact
          end
          data.except('include_translation')
        end

        def self.transform_embedded(data, utility_object)
          template = DataCycleCore::Thing.find_by(template_name: data.dig('template_name'), template: true)
          # byebug
          template.embedded_property_names&.each do |embedded|
            data[embedded] = data[embedded]&.map { |item|
              handle_embedded(item, utility_object)
            }&.try(:compact)
          end
          data
        end

        def self.handle_embedded(data, utility_object)
          return nil if data[I18n.locale.to_s].blank?
          template = DataCycleCore::Thing.find_by(template_name: data.dig(I18n.locale.to_s, 'template_name'))
          return nil if template.blank?
          # treat linked
          linked_key_translation = DataCycleCore::Generic::DcSync::Processing.process_included_items(utility_object, template, data.dig('included'))
          embedded = data[I18n.locale.to_s]
          embedded = transform_linked_keys(embedded.merge({ 'include_translation' => linked_key_translation }))

          embedded['external_key'] = embedded['id']
          embedded['external_source_id'] = utility_object.external_source.id
          TransformationFunctions.create_thing(embedded['id'], template, utility_object.external_source) if DataCycleCore::Thing.find_by(id: embedded['id']).blank?
          embedded.delete('external_system_syncs')

          embedded = embedded.merge(transform_embedded(embedded, utility_object.external_source.id))
          embedded
        end

        def self.get_template(data)
          locale = data.keys.except(['included', 'attribute_name']).first
          DataCycleCore::Thing.find_by(template_name: data.dig(locale, 'template_name'), template: true)
        end
      end
    end
  end
end
