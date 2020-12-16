# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Processing
        def self.process_things(utility_object, raw_data, template, config)
          item_template = get_template(raw_data)
          linked_key_translation = process_included_items(utility_object, item_template, raw_data.dig('included'))
          classification_key_translation = process_classifications(utility_object, item_template, raw_data.dig('classifications'))
          processed_thing = nil
          raw_data.except('included', 'classifications', 'attribute_name', 'include_translation').each_key do |locale|
            I18n.with_locale(locale) do
              data_correct_linked = transform_linked_keys(data: raw_data[locale].except('included', 'classifications'), lookup: linked_key_translation)
              data_correct_ids = transform_classification_keys(data: data_correct_linked, lookup: classification_key_translation)
              data_correct_embedded = transform_embedded(data_correct_ids, utility_object)

              processed_thing = DataCycleCore::Generic::Common::ImportFunctions.process_step(
                utility_object: utility_object,
                raw_data: data_correct_embedded,
                transformation: DataCycleCore::Generic::DcSync::Transformations.to_thing(utility_object.external_source),
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

        def self.transform_linked_keys(data:, lookup:)
          lookup&.each_key do |property_name|
            data[property_name] = Array.wrap(data[property_name])
              .map { |item| lookup[property_name][item] }
              .compact
          end
          data.except('include_translation')
        end

        def self.transform_classification_keys(data:, lookup:)
          universal_classifications = lookup['universal_classification']&.values || []
          lookup&.each_key do |property_name|
            data[property_name] = lookup[property_name]&.values || []
          end
          data['universal_classifications'] = universal_classifications
          data
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
          linked_key_translation = process_included_items(utility_object, template, data.dig('included'))
          classification_key_translation = process_classifications(utility_object, template, data.dig('classifications'))
          embedded = data[I18n.locale.to_s]
          embedded = transform_linked_keys(data: embedded, lookup: linked_key_translation)
          embedded = transform_classification_keys(data: embedded, lookup: classification_key_translation)

          embedded['external_key'] = embedded['id']
          embedded['external_source_id'] = utility_object.external_source.id
          TransformationFunctions.create_thing(embedded['id'], template, utility_object.external_source) if DataCycleCore::Thing.find_by(id: embedded['id']).blank?
          embedded.delete('external_system_syncs')

          embedded = embedded.merge(transform_embedded(embedded, utility_object))
          embedded
        end

        def self.get_template(data)
          locale = data.keys.except(['included', 'attribute_name']).first
          DataCycleCore::Thing.find_by(template_name: data.dig(locale, 'template_name'), template: true)
        end

        def self.process_classifications(utility_object, template, classifications)
          classification_translation = {}
          known_classification_names = template.classification_property_names
          classifications&.each do |classification|
            classification_attribute_name = classification['attribute_name']
            if known_classification_names.include?(classification['attribute_name'])
              expected_tree_label = template.properties_for(classification['attribute_name']).dig('tree_label')
              imported_tree_label = classification.dig('ancestors').detect { |i| i.dig('class_type') == 'DataCycleCore::ClassificationTreeLabel' }.dig('name')
              raise DataCycleCore::Generic::Common::Error::GenericError, "DcSync tried to import classifications for property_name: #{classification['attribute_name']} from tree #{imported_tree_label}. Expected was tree_label #{expected_tree_label}." if expected_tree_label != imported_tree_label
            else
              classification_attribute_name = 'universal_classification'
            end
            classification_translation[classification_attribute_name] ||= {}
            translated_id = import_classification_path(external_source: utility_object.external_source, data: classification)
            classification_translation[classification_attribute_name][classification['id']] = translated_id
          end
          classification_translation
        end

        def self.import_classification_path(external_source:, data:)
          classification_lookup = {} # for this specific path
          tree_label_data = data.dig('ancestors').detect { |i| i.dig('class_type') == 'DataCycleCore::ClassificationTreeLabel' }
          aliases_path = data.dig('ancestors').select { |i| i.dig('class_type') == 'DataCycleCore::ClassificationAlias' }

          # insert all classification_data along the tree path
          parent_aliases = [nil] + aliases_path.reverse
          parent_aliases.zip(aliases_path.reverse).map do |parent_data, aliases_data|
            next if aliases_data.blank?
            parent_id = classification_lookup[parent_data&.dig('id')]
            classification_lookup[aliases_data.dig('id')] = import_classification(
              external_source: external_source,
              classification_data: aliases_data['primary_classification'],
              alias_data: aliases_data.except('primary_classification'),
              tree_label_data: tree_label_data,
              parent_id: parent_id
            )
          end
          classification_lookup[aliases_path.first.dig('id')]
        end

        def self.import_classification(external_source:, classification_data:, alias_data:, tree_label_data:, parent_id:)
          external_source_id = external_source.id
          internal = alias_data.dig('internal')
          parent_classification_alias = nil
          parent_classification_alias = DataCycleCore::Classification.find(parent_id).primary_classification_alias if parent_id.present?

          external_system = external_source_id
          external_system = nil if internal
          if classification_data[:external_system].present?
            external_system = DataCycleCore::ExternalSystem
              .find_or_create_by(
                name: classification_data[:external_system],
                identifier: classification_data[:external_system]
              ).id
          end

          if classification_data[:external_key].blank?
            classification = DataCycleCore::Classification
              .find_or_initialize_by(
                external_source_id: external_system,
                name: classification_data[:name]
              )
          else
            classification = DataCycleCore::Classification
              .find_or_initialize_by(
                external_source_id: external_system,
                external_key: classification_data[:external_key]
              ) do |c|
                c.name = classification_data[:name]
              end
          end

          if classification.new_record?
            classification_alias = DataCycleCore::ClassificationAlias.create!(
              alias_data
                .except('id', 'class_type', 'external_system')
                .merge({ 'external_source_id' => external_system })
            )

            DataCycleCore::ClassificationGroup.create!(
              classification: classification,
              classification_alias: classification_alias,
              external_source_id: external_system
            )

            tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(
              tree_label_data
                .except('id', 'class_type', 'external_system')
                .merge('external_source_id' => external_system)
            ) do |item|
              item.visibility = DataCycleCore.default_classification_visibilities
              item.internal = false
            end

            DataCycleCore::ClassificationTree.create!(
              {
                classification_tree_label: tree_label,
                parent_classification_alias: parent_classification_alias,
                sub_classification_alias: classification_alias
              }
            )
          else
            primary_classification_alias = classification.primary_classification_alias
            primary_classification_alias.attributes = alias_data.slice('name_i18n', 'description_i18n', 'uri')
            primary_classification_alias.name_i18n = alias_data['name_i18n']&.slice(*I18n.available_locales)
            primary_classification_alias.description_i18n = alias_data['description_i18n']&.slice(*I18n.available_locales)
            primary_classification_alias.save!

            classification_tree = primary_classification_alias.classification_tree
            classification_tree.parent_classification_alias = parent_classification_alias
            classification_tree.save!
          end

          classification.attributes = classification_data
            .except('id', 'class_type', 'external_system')
            .merge({ 'external_source_id' => external_system })
          classification.save!
          classification.id
        end
      end
    end
  end
end
