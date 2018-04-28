module DataCycleCore
  module Generic
    class ImportBase < Base
      protected

      def import_classifications(type, tree_name, load_root_classifications, load_child_classifications,
                                 load_parent_classification_alias, extract_data, **options)
        raise ArgumentError('tree_name cannot be blank') if tree_name.blank?

        around_import(type, **options) do |locale|
          phase_name = type.collection_name

          item_count = 0

          begin
            @logging.phase_started("#{phase_name}_#{locale}")

            @source_object.with(type) do |mongo_item|
              raw_classification_data_stack = load_root_classifications.call(mongo_item, locale).to_a

              while (raw_classification_data = raw_classification_data_stack.pop.try(:[], 'dump').try(:[], locale))
                item_count += 1

                extracted_classification_data = extract_data.call(raw_classification_data)

                import_classification(
                  extracted_classification_data.merge({ tree_name: tree_name }),
                  load_parent_classification_alias.call(raw_classification_data)
                )
                raw_classification_data_stack += load_child_classifications.call(mongo_item, raw_classification_data, locale).to_a

                @logging.item_processed(
                  extracted_classification_data[:name],
                  extracted_classification_data[:id],
                  item_count,
                  nil
                )

                break if options[:max_count] && item_count >= options[:max_count]
              end
            end
          ensure
            @logging.phase_finished("#{phase_name}_#{locale}", item_count)
          end
        end
      end

      def import_classification(classification_data, parent_classification_alias = nil)
        if classification_data[:external_id].blank?
          classification = DataCycleCore::Classification
            .find_or_initialize_by(
              external_source_id: external_source.id,
              name: classification_data[:name]
            )

        else
          classification = DataCycleCore::Classification
            .find_or_initialize_by(
              external_source_id: external_source.id,
              external_key: classification_data[:external_id]
            )
        end

        classification.name = classification_data[:name]
        classification.external_key = classification_data[:external_id]

        if classification.new_record?
          classification_alias = DataCycleCore::ClassificationAlias.create!(
            external_source_id: external_source.id,
            name: classification_data[:name]
          )

          classification_group = DataCycleCore::ClassificationGroup.create!(
            classification: classification,
            classification_alias: classification_alias,
            external_source_id: external_source.id
          )

          tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(
            external_source_id: external_source.id,
            name: classification_data[:tree_name]
          )

          classification_tree = DataCycleCore::ClassificationTree.create!(
            {
              classification_tree_label: tree_label,
              parent_classification_alias: parent_classification_alias,
              sub_classification_alias: classification_alias
            }
          )
        else
          primary_classification_alias = classification.primary_classification_alias
          primary_classification_alias.name = classification_data[:name]
          primary_classification_alias.save!

          classification_tree = primary_classification_alias.classification_tree
          classification_tree.parent_classification_alias = parent_classification_alias
          classification_tree.save!

          classification_alias = primary_classification_alias
        end
        classification.save!
        classification_alias
      end

      def import_contents(source_type, target_type, load_contents, process_content, **options)
        around_import(source_type, **options) do |locale|
          phase_name = source_type.collection_name

          item_count = 0
          fixnum_max = (2**(0.size * 4 - 2) - 1)
          begin
            @logging.phase_started("#{phase_name}_#{locale}")

            @source_object.with(source_type) do |mongo_item|
              load_contents.call(mongo_item, locale).all.no_timeout.max_time_ms(fixnum_max).each do |content|
                item_count += 1

                process_content.call(content[:dump][locale], load_template(target_type, @data_template), locale)

                break if options[:max_count] && item_count >= options[:max_count]
              end
            end
          ensure
            @logging.phase_finished("#{phase_name}_#{locale}", item_count)
          end
        end
      end

      def create_or_update_content(clazz, template, data)
        return nil if data.except('external_key', 'locale').blank?

        content = clazz.find_or_initialize_by(
          external_source_id: external_source.id,
          external_key: data['external_key']
        )
        content.metadata ||= {}
        content.schema = template.schema
        content.template_name = template.template_name
        content.save!

        error = content.set_data_hash(data_hash: (content.get_data_hash || {}).merge(data), prevent_history: true)

        if @logging && !error[:error].blank?
          @logging.error('Validating import data', data['external_key'], data, error[:error].values.flatten.join('\n'))
        elsif !error[:error].blank?
          raise error[:error].first
        end

        content.tap(&:save!)
      end

      private

      def load_default_values(data_hash)
        return nil if data_hash.blank?
        return_data = {}
        data_hash.each do |key, value|
          return_data[key] = default_classification(value.symbolize_keys)
        end
        return_data.reject { |_, value| value.blank? }
      end

      def default_classification(value:, tree_label:)
        [
          DataCycleCore::Classification
            .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
            .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })&.first&.id
        ].reject(&:nil?)
      end

      def load_template(target_type, template_name)
        I18n.with_locale(:de) do
          target_type.find_by!(template: true, template_name: template_name)
        end
      rescue ActiveRecord::RecordNotFound
        raise "Missing template #{template_name} for #{target_type}"
      end

      def merge_default_values(item, data_hash)
        new_hash = {}
        new_hash = load_default_values(@options.dig(:import, :default_values, item)) if @options.dig(:import, :default_values, item).present?
        new_hash.merge(data_hash)
      end

      def around_import(source_type, **options)
        options[:locales] ||= options[:import][:locales] || I18n.available_locales

        options[:locales].each do |locale|
          begin
            Mongoid.override_database("#{source_type.database_name}_#{external_source.id}")

            yield(locale.to_sym)
          ensure
            Mongoid.override_database(nil)
          end
        end
      end
    end
  end
end
