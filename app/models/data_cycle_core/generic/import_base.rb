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

    def import_contents(source_type, target_type, load_contents, process_content, **options)
      around_import(source_type, **options) do |locale|
        phase_name = source_type.to_s.demodulize.underscore.pluralize

        item_count = 0

        begin
          @logging.phase_started("#{phase_name}_#{locale}")

          load_contents.call(locale).each do |content|
            item_count += 1

            process_content.call(content[:dump][locale], load_template(target_type, content[:dump][locale]), locale)

            break if options[:max_count] && item_count >= options[:max_count]
          end
        ensure
          @logging.phase_finished("#{phase_name}_#{locale}", item_count)
        end
      end
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

    def load_template(target_type, raw_data)
      if self.class.to_s.deconstantize.constantize.content_template.nil?
        raise 'Missing configuration for content templates'
      elsif self.class.to_s.deconstantize.constantize.content_template.is_a? String
        begin
          target_type.find_by!(template: true, headline: self.class.to_s.deconstantize.constantize.content_template)
        rescue ActiveRecord::RecordNotFound
          raise "Missing template #{self.class.to_s.deconstantize.constantize.content_template} for #{target_type}"
        end
      elsif self.class.to_s.deconstantize.constantize.content_template.is_a? Proc
        begin
          target_type.find_by!(
            template: true,
            headline: self.class.to_s.deconstantize.constantize.content_template.call(raw_data)
          )
        rescue ActiveRecord::RecordNotFound
          raise "Missing template #{self.class.to_s.deconstantize.constantize.content_template.call(raw_data)} \
                for #{target_type}"
        end
      else
        raise NotImplementedError
      end
    end

    def poi_template(raw_data)
      # if DataCycleCore::OutdoorActive.poi_template.nil?
      #   @log.error 'Missing configuration for poi template to use when importing pois from outdoor active'
      #   raise 'Missing configuration for poi template'
      # elsif DataCycleCore::OutdoorActive.poi_template.is_a? String
      #   begin
      #     Place.find_by!(template: true, headline: DataCycleCore::OutdoorActive.poi_template)
      #   rescue ActiveRecord::RecordNotFound => e
      #     @log.error "Missing template '#{DataCycleCore::OutdoorActive.poi_template}' for places"
      #     raise e
      #   end
      # elsif DataCycleCore::OutdoorActive.poi_template.is_a? Proc
      #   begin
      #     Place.find_by!(template: true, headline: DataCycleCore::OutdoorActive.poi_template.call(raw_data))
      #   rescue ActiveRecord::RecordNotFound => e
      #     @log.error "Missing template '#{DataCycleCore::OutdoorActive.poi_template.call(raw_data)}' for places"
      #     raise e
      #   end
      # else
      #   raise NotImplementedError
      # end
    end
  end
end
