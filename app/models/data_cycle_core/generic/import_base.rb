module DataCycleCore::Generic
  class ImportBase < Base

    protected

    def import_classifications(type, tree_name, load_root_classifications, load_child_classifications,
                               load_parent_classification_alias, extract_data, **options)
      around_import(type, **options) do |locale|
        phase_name = type.to_s.demodulize.underscore.pluralize

        item_count = 0

        begin
          @logging.phase_started("#{phase_name}_#{locale}")

          raw_classification_data_stack = load_root_classifications.(locale).to_a

          while (raw_classification_data = raw_classification_data_stack.pop.try(:[], 'dump').try(:[], locale))
            item_count += 1

            extracted_classification_data = extract_data.(raw_classification_data)

            import_classification(extracted_classification_data.merge({tree_name: tree_name}),
                                  load_parent_classification_alias.(raw_classification_data))

            raw_classification_data_stack += load_child_classifications.call(raw_classification_data, locale).to_a

            @logging.item_processed(extracted_classification_data[:name],
                                    extracted_classification_data[:id], item_count, nil)

            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          @logging.phase_finished("#{phase_name}_#{locale}", item_count)
        end
      end
    end

    def import_classification(classification_data, parent_classification_alias = nil)
      if classification_data[:external_id].blank?
        classification = DataCycleCore::Classification
          .find_or_initialize_by(external_source_id: external_source.id,
                                 name: classification_data[:name])

      else
        classification = DataCycleCore::Classification
          .find_or_initialize_by(external_source_id: external_source.id,
                                 external_key: classification_data[:external_id])
      end
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

    def import_contents(source_type, target_type, load_contents, process_content, **options)
      around_import(source_type, **options) do |locale|
        phase_name = source_type.to_s.demodulize.underscore.pluralize

        item_count = 0

        begin
          @logging.phase_started("#{phase_name}_#{locale}")

          load_contents.call(locale).each do |content|
            item_count += 1

            process_content.call(content[:dump][locale], load_template(target_type, @data_template), locale)

            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          @logging.phase_finished("#{phase_name}_#{locale}", item_count)
        end
      end
    end

    def create_or_update_content(clazz, template, data)
      return nil if data.except('external_key', 'locale').blank?

      content = clazz.find_or_initialize_by(external_source_id: external_source.id,
                                            external_key: data['external_key'])
      content.metadata ||= {}
      content.metadata['validation'] = template.metadata['validation']

      old_data = content.get_data_hash || {}
      content.set_data_hash(old_data.merge(data))

      content.tap(&:save!)
    end

    private

    def around_import(source_type, **options)
      options[:locales] ||= I18n.available_locales

      options[:locales].each do |locale|
        begin
          Mongoid.override_database("#{source_type.database_name}_#{external_source.id}")

          yield(locale)
        ensure
          Mongoid.override_database(nil)
        end
      end
    end

    def load_template(target_type, template_name)
      begin
        target_type.find_by!(template: true, headline: template_name)
      rescue ActiveRecord::RecordNotFound
        raise "Missing template #{template_name} for #{target_type}"
      end
    end

  end
end
