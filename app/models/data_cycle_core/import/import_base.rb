module DataCycleCore::Import
  class ImportBase < Base

    protected

    def import_classifications(type, tree_name, load_root_classifications, load_child_classifications,
                               load_parent_classification_alias, extract_data,
                               callbacks = DataCycleCore::Callbacks.new, **options)
      options[:locales] ||= I18n.available_locales

      if options[:locales].size != 1
        options[:locales].each do |l|
          import_classifications(type, extract_id, extract_name, callbacks,
                                 options.except(:locales).merge({locales: [l]}))
        end
      else
        locale = options[:locales].first

        item_count = 0

        begin
          Mongoid.override_database("#{type.database_name}_#{external_source.id}")

          callbacks.execute_callback(:phase_started, "#{type.to_s.demodulize.underscore.pluralize}_#{locale}")

          raw_classification_data_stack = load_root_classifications.(locale).to_a

          while(raw_classification_data = raw_classification_data_stack.pop.try(:[], 'dump').try(:[], locale)) do
            item_count += 1

            extracted_classification_data = extract_data.(raw_classification_data)

            import_classification(extracted_classification_data.merge({tree_name: tree_name}),
                                  load_parent_classification_alias.(raw_classification_data))

            raw_classification_data_stack += load_child_classifications.call(raw_classification_data, locale).to_a

            callbacks.execute_callback(:item_processed, extracted_classification_data[:name],
                                       extracted_classification_data[:id], item_count, nil)
          end
        ensure
          Mongoid.override_database(nil)

          callbacks.execute_callback(:phase_finished, "#{type.to_s.demodulize.underscore.pluralize}_#{locale}",
                                     item_count)
        end
      end
    end

    def import_classification(classification_data, parent_classification_alias = nil)
      classification = DataCycleCore::Classification
        .find_or_initialize_by(external_source_id: external_source.id,
                               external_key: classification_data[:external_id])
      if classification.new_record?
        classification.name = classification_data[:name]
        classification.save!

        classification_alias = DataCycleCore::ClassificationAlias.create!(external_source_id: external_source.id,
                                                                          name: classification_data[:name])

        classification_group = DataCycleCore::ClassificationGroup.create!(classification: classification,
                                                                          classification_alias: classification_alias)

        tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(external_source_id: external_source.id,
                                                                              name: classification_data[:tree_name])

        classification_tree = DataCycleCore::ClassificationTree.create!({
          classification_tree_label: tree_label,
          parent_classification_alias: parent_classification_alias,
          sub_classification_alias: classification_alias
        })

        classification_alias
      else
        classification.name = classification_data[:name]
        classification.save!

        primary_classification_alias = classification.primary_classification_alias
        primary_classification_alias.name = classification_data[:name]
        primary_classification_alias.save!

        classification_tree = primary_classification_alias.classification_tree
        classification_tree.parent_classification_alias = parent_classification_alias
        classification_tree.save!

        primary_classification_alias
      end
    end
  end
end
