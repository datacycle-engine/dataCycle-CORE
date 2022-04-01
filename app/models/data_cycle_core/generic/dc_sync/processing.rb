# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DcSync
      module Processing
        def self.process_only_sync(utility_object, raw_data, template, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DcSync::Transformations.to_thing(utility_object.external_source.id),
            default: { template: template },
            config: config.dig(:import, :transformations)
          )
        end

        def self.process_things(utility_object, raw_data, template, config)
          item_template = get_template(raw_data)
          raw_data = process_namespaced_trees(utility_object, raw_data, config&.dig(:import, :transformations, :namespace_trees)) if config&.dig(:import, :transformations, :namespace_trees).present?
          linked_key_translation = process_included_items(utility_object, item_template, raw_data.dig('included'), config)
          classification_key_translation = process_classifications(utility_object, item_template, raw_data.dig('classifications'), config&.dig(:import, :transformations, :exclude_trees))
          processed_thing = nil
          raw_data
            .except('included', 'classifications', 'attribute_name', 'include_translation')
            .keys
            .select { |i| i.to_sym.in?(I18n.available_locales) }
            .each do |locale|
            I18n.with_locale(locale) do
              data_mapped_classifications = transform_classification_maps(data: raw_data[locale].except('included', 'classifications'), lookup: config&.dig(:import, :transformations, :namespace_trees))
              data_correct_linked = transform_linked_keys(data: data_mapped_classifications, lookup: linked_key_translation)
              data_correct_ids = transform_classification_keys(data: data_correct_linked, lookup: classification_key_translation)
              data_correct_embedded = transform_embedded(data_correct_ids, utility_object, config)
              data_corrected = data_correct_embedded.except(*(config&.dig(:import, :transformations, :exclude_properties) || []))
              processed_thing = DataCycleCore::Generic::Common::ImportFunctions.process_step(
                utility_object: utility_object,
                raw_data: data_corrected,
                transformation: DataCycleCore::Generic::DcSync::Transformations.to_thing(utility_object.external_source.id),
                default: { template: template },
                config: config.dig(:import, :transformations)
              )
            end
          end
          processed_thing
        end

        def self.process_included_items(utility_object, parent_template, included_items, config)
          linked_key_translation = {}
          included_items&.each do |included_item|
            attribute_name = included_item.dig('attribute_name')
            locale = included_item.except('included', 'attribute_name').keys.first
            template_name = included_item.dig(locale, 'template_name')
            next if attribute_name.blank?
            next unless parent_template.property_names.include?(attribute_name)
            linked_key_translation[included_item.dig('attribute_name')] ||= {}
            if DataCycleCore::Thing.find_by(template: true, template_name: template_name).blank?
              linked_key_translation[attribute_name][included_item[locale]['id']] = []
            else
              item = DataCycleCore::Generic::DcSync::Import.process_content(
                utility_object: utility_object,
                raw_data: included_item,
                options: config || {}
              )
              linked_key_translation[attribute_name][included_item[locale]['id']] = item&.id
            end
          end
          linked_key_translation
        end

        def self.transform_classification_maps(data:, lookup:)
          return data if lookup.blank?
          universal_classifications = data['universal_classifications'] || []
          lookup&.each do |hash|
            next if data[hash[:attribute_name]].blank?
            universal_classifications += data[hash[:attribute_name]]
            data.delete(hash[:attribute_name])
          end
          data['universal_classifications'] = universal_classifications
          data
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
          universal_classifications = lookup['universal_classifications']&.values || []
          lookup&.each_key do |property_name|
            data[property_name] = lookup[property_name]&.values&.compact || []
          end
          data['universal_classifications'] = universal_classifications
          data
        end

        def self.transform_embedded(data, utility_object, config)
          template = DataCycleCore::Thing.find_by(template_name: data.dig('template_name'), template: true)
          template.embedded_property_names&.each do |embedded|
            data[embedded] = data[embedded]&.map { |item|
              handle_embedded(item, utility_object, config)
            }&.try(:compact)
          end
          data
        end

        def self.handle_embedded(data, utility_object, config)
          return nil if data[I18n.locale.to_s].blank?
          template = get_template(data, 'embedded')
          return nil if template.blank?
          # treat linked
          linked_key_translation = process_included_items(utility_object, template, data.dig('included'), config)
          data = process_namespaced_trees(utility_object, data, config&.dig(:import, :transformations, :namespace_trees)) if config&.dig(:import, :transformations, :namespace_trees).present?
          classification_key_translation = process_classifications(utility_object, template, data.dig('classifications'), config&.dig(:import, :transformations, :exclude_trees))
          embedded = data[I18n.locale.to_s]
          embedded = transform_classification_maps(data: embedded, lookup: config&.dig(:import, :transformations, :namespace_trees))
          embedded = transform_linked_keys(data: embedded, lookup: linked_key_translation)
          embedded = transform_classification_keys(data: embedded, lookup: classification_key_translation)

          embedded['external_key'] = embedded['id']
          embedded['external_source_id'] = utility_object.external_source.id
          TransformationFunctions.create_thing(embedded['id'], template, utility_object.external_source) if DataCycleCore::Thing.find_by(id: embedded['id']).blank?
          embedded.delete('external_system_syncs')

          embedded = embedded.merge(transform_embedded(embedded, utility_object, config))
          embedded
        end

        def self.get_template(data, content_type = ['entity', 'container'])
          locale = data.keys.except(['included', 'attribute_name']).first
          DataCycleCore::Thing.find_by(template_name: data.dig(locale, 'template_name'), template: true, content_type: content_type)
        end

        def self.process_namespaced_trees(utility_object, raw_data, namespace_trees)
          namespaced_attributes = namespace_trees.map { |i| i[:attribute_name] }
          transformed_classifications = raw_data.dig('classifications')&.map do |classification|
            if classification['attribute_name'].in?(namespaced_attributes)
              transformed_ancestors = classification['ancestors']&.map do |ancestor|
                if ancestor['class_type'] == 'DataCycleCore::ClassificationTreeLabel'
                  name_hash = namespace_trees.detect { |i| i[:attribute_name] == classification['attribute_name'] && i[:old_name] == ancestor['name'] }
                  if name_hash.present?
                    ancestor['name'] = name_hash[:new_name]
                  else
                    ancestor['name'] = "#{ancestor['name']} (#{utility_object.external_source.name})"
                  end
                end
                ancestor
              end
              classification['attribute_name'] = 'universal_classifications'
              classification['ancestors'] = transformed_ancestors
            end
            classification
          end
          raw_data['classifications'] = transformed_classifications
          raw_data
        end

        def self.process_classifications(utility_object, template, classifications, exclude_trees)
          classification_translation = {}
          known_classification_names = template.classification_property_names
          classifications&.each do |classification|
            classification_attribute_name = classification['attribute_name']
            imported_tree_label = classification.dig('ancestors').detect { |i| i.dig('class_type') == 'DataCycleCore::ClassificationTreeLabel' }.dig('name')
            if known_classification_names.include?(classification['attribute_name']) && classification['attribute_name'] != 'universal_classifications'
              expected_tree_label = template.properties_for(classification['attribute_name']).dig('tree_label')
              raise DataCycleCore::Generic::Common::Error::GenericError, "DcSync tried to import classifications for property_name: #{classification['attribute_name']} from tree #{imported_tree_label}. Expected was tree_label #{expected_tree_label}." if expected_tree_label != imported_tree_label
            else
              classification_attribute_name = 'universal_classifications'
            end
            classification_translation[classification_attribute_name] ||= {}
            if exclude_trees.present? && imported_tree_label.in?(exclude_trees)
              classification_translation[classification_attribute_name][classification['id']] = nil
            else
              translated_id = import_classification_path(external_source: utility_object.external_source, data: classification)
              classification_translation[classification_attribute_name][classification['id']] = translated_id
            end
            classification_translation[classification_attribute_name].compact!
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
            given_source = nil
            if aliases_data['external_system'].present?
              given_source = DataCycleCore::ExternalSystem.find_by('identifier = ? OR name = ?', aliases_data['external_system'], aliases_data['external_system'])
              given_source = DataCycleCore::ExternalSystem.create(name: aliases_data[:external_system], identifier: aliases_data[:external_system]) if given_source.blank?
            end
            classification_external_source = given_source || external_source
            parent_id = classification_lookup[parent_data&.dig('id')]
            classification_lookup[aliases_data.dig('id')] = import_classification(
              external_source: classification_external_source,
              classification_data: aliases_data['primary_classification'],
              alias_data: aliases_data.except('primary_classification'),
              tree_label_data: tree_label_data,
              parent_id: parent_id
            )
          end
          classification_lookup[aliases_path.first.dig('id')]
        end

        def self.import_classification(external_source:, classification_data:, alias_data:, tree_label_data:, parent_id:)
          parent_classification_alias = nil
          parent_classification_alias = DataCycleCore::Classification.find(parent_id).primary_classification_alias if parent_id.present?

          tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label_data.dig('name'))
          if tree_label.present?
            external_system = tree_label.external_source_id
          else
            external_system = external_source.id
          end

          if classification_data[:external_key].blank?
            # in case multiple classifications have the same name
            if tree_label.present?
              classification = DataCycleCore::ClassificationAlias
                .for_tree(tree_label.name)
                .find_by(internal_name: classification_data['name'])
                &.primary_classification
            end
            if classification.blank?
              classification = DataCycleCore::Classification.new(
                external_source_id: external_system,
                name: classification_data[:name]
              )
            end
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
            name_i18n = alias_data['name_i18n']&.slice(*I18n.available_locales.map(&:to_s))
            description_i18n = alias_data['description_i18n']&.slice(*I18n.available_locales.map(&:to_s))
            classification_alias = DataCycleCore::ClassificationAlias.create!(
              alias_data
                .slice('name', 'description', 'internal_name', 'uri')
                .merge({
                  'external_source_id' => external_system,
                  'name_i18n' => name_i18n,
                  'description_i18n' => description_i18n
                })
            )

            DataCycleCore::ClassificationGroup.create!(
              classification: classification,
              classification_alias: classification_alias,
              external_source_id: external_system
            )

            tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(
              tree_label_data
                .slice('name')
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
            primary_classification_alias.uri = primary_classification_alias.uri || alias_data['uri']
            primary_classification_alias.name_i18n = (primary_classification_alias.name_i18n || {}).reverse_merge((alias_data['name_i18n']&.slice(*I18n.available_locales.map(&:to_s)) || {}))
            primary_classification_alias.description_i18n = (primary_classification_alias.description_i18n || {}).reverse_merge((alias_data['description_i18n']&.slice(*I18n.available_locales.map(&:to_s)) || {}))
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
