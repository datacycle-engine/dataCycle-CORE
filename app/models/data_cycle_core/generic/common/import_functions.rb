# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctions
        def self.process_step(utility_object:, raw_data:, transformation:, default:, config:)
          type = config&.dig(:content_type)&.constantize || default.dig(:content_type)
          template = config&.dig(:template) || default.dig(:template)
          create_or_update_content(
            utility_object: utility_object,
            class_type: type,
            template: load_template(type, template),
            data: merge_default_values(
              config,
              transformation.call(raw_data)
            ).with_indifferent_access
          )
        end

        def self.create_or_update_content(utility_object:, class_type:, template:, data:)
          return nil if data.except('external_key', 'locale').blank?

          content = class_type.find_or_initialize_by(
            external_source_id: utility_object.external_source.id,
            external_key: data['external_key']
          )
          content.metadata ||= {}
          content.schema = template.schema
          content.template_name = template.template_name
          content.save!

          # TODO: (MO) still convinced that (content.get_data_hash || {}).merge(data) <-- is in some circumstances wrong!!
          overlays = {}
          DataCycleCore::Feature::OverlayAttributeService.call(content).each do |attribute|
            overlays[attribute] = [content.send(attribute).first&.get_data_hash] if content.respond_to?(attribute)
          end
          error = content.set_data_hash(data_hash: overlays.merge(data), prevent_history: true)

          if utility_object.logging && error[:error].present?
            utility_object.logging.error('Validating import data', data['external_key'], data, error[:error].values.flatten.join('\n'))
          elsif error[:error].present?
            ap error
            #raise error[:error].first
          end

          content.tap(&:save!)
        end

        def self.import_contents(utility_object:, iterator:, data_processor:, options:)
          if options&.dig(:iteration_strategy).blank?
            import_sequential(utility_object: utility_object, iterator: iterator, data_processor: data_processor, options: options)
          else
            send(options.dig(:iteration_strategy), utility_object: utility_object, iterator: iterator, data_processor: data_processor, options: options)
          end
        end

        def self.import_sequential(utility_object:, iterator:, data_processor:, options:)
          delta = 100
          init_logging(options) do |logging|
            init_mongo_db(utility_object) do
              phase_name = utility_object.source_type.collection_name
              logging.preparing_phase("#{utility_object.external_source.name} #{phase_name}")
              each_locale(utility_object.locales) do |locale|
                item_count = 0
                fixnum_max = (2**(0.size * 4 - 2) - 1)
                begin
                  logging.phase_started("#{phase_name} #{locale}")
                  source_filter = options&.dig(:import, :source_filter) || {}
                  durations = []

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    iterator.call(mongo_item, locale, source_filter).all.no_timeout.max_time_ms(fixnum_max).each do |content|
                      durations << Benchmark.realtime do
                        item_count += 1

                        data_processor.call(
                          utility_object: utility_object,
                          raw_data: content[:dump][locale],
                          locale: locale,
                          options: options
                        )

                        next unless (item_count % delta).zero?

                        GC.start
                        logging.info("Imported #{item_count} items in #{durations.sum.round(6)} seconds", "ðt: #{durations[-(delta + 1)..-1]&.sum&.round(6)}")
                      end
                      break if options[:max_count].present? && item_count >= options[:max_count]
                    end
                  end
                ensure
                  logging.phase_finished("#{phase_name}_#{locale}", item_count)
                end
              end
            end
          end
        end

        def self.init_mongo_db(utility_object)
          Mongoid.override_database("#{utility_object.source_type.database_name}_#{utility_object.external_source.id}")
          yield
        ensure
          Mongoid.override_database(nil)
        end

        def self.each_locale(locales)
          locales.each do |locale|
            yield(locale.to_sym)
          end
        end

        def self.init_logging(options)
          if options&.dig(:import, :logging_strategy).blank?
            logging = DataCycleCore::Generic::Logger::LogFile.new('import')
          else
            logging = instance_eval(options.dig(:import, :logging_strategy))
          end
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end

        def self.load_default_values(data_hash)
          return nil if data_hash.blank?
          return_data = {}
          data_hash.each do |key, value|
            return_data[key] = default_classification(value.symbolize_keys)
          end
          return_data.reject { |_, value| value.blank? }
        end

        def self.load_template(target_type, template_name)
          I18n.with_locale(:de) do
            target_type.find_by!(template: true, template_name: template_name)
          end
        rescue ActiveRecord::RecordNotFound
          raise "Missing template #{template_name} for #{target_type}"
        end

        def self.default_classification(value:, tree_label:)
          [
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })&.first&.id
          ].reject(&:nil?)
        end

        def self.merge_default_values(config, data_hash)
          new_hash = {}
          new_hash = load_default_values(config.dig(:default_values)) if config&.dig(:default_values).present?
          new_hash.merge(data_hash)
        end

        def self.import_classifications(utility_object, tree_name, load_root_classifications, load_child_classifications,
                                        load_parent_classification_alias, extract_data, options)
          raise ArgumentError('tree_name cannot be blank') if tree_name.blank?

          external_source_id = utility_object.external_source.id
          init_logging(options) do |logging|
            init_mongo_db(utility_object) do
              each_locale(utility_object.locales) do |locale|
                phase_name = utility_object.source_type.collection_name

                item_count = 0

                begin
                  logging.phase_started("#{phase_name}_#{locale}")

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    raw_classification_data_stack = load_root_classifications.call(mongo_item, locale, options).to_a

                    while (raw_classification_data = raw_classification_data_stack.pop.try(:[], 'dump')&.dig(locale))
                      item_count += 1

                      extracted_classification_data = extract_data.call(options, raw_classification_data)

                      import_classification(
                        utility_object: utility_object,
                        classification_data: extracted_classification_data.merge({ tree_name: tree_name }),
                        parent_classification_alias: load_parent_classification_alias.call(raw_classification_data, external_source_id)
                      )
                      raw_classification_data_stack += load_child_classifications.call(mongo_item, raw_classification_data, locale).to_a

                      logging.item_processed(
                        extracted_classification_data[:name],
                        extracted_classification_data[:id],
                        item_count,
                        nil
                      )

                      break if options[:max_count] && item_count >= options[:max_count]
                    end
                  end
                ensure
                  logging.phase_finished("#{phase_name}_#{locale}", item_count)
                end
              end
            end
          end
        end

        def self.import_classification(utility_object:, classification_data:, parent_classification_alias: nil)
          if classification_data[:external_key].blank?
            classification = DataCycleCore::Classification
              .find_or_initialize_by(
                external_source_id: utility_object.external_source.id,
                name: classification_data[:name]
              )
          else
            classification = DataCycleCore::Classification
              .find_or_initialize_by(
                external_source_id: utility_object.external_source.id,
                external_key: classification_data[:external_key]
              )
          end

          classification.name = classification_data[:name]
          classification.external_key = classification_data[:external_key]

          if classification.new_record?
            classification_alias = DataCycleCore::ClassificationAlias.create!(
              external_source_id: utility_object.external_source.id,
              name: classification_data[:name]
            )

            DataCycleCore::ClassificationGroup.create!(
              classification: classification,
              classification_alias: classification_alias,
              external_source_id: utility_object.external_source.id
            )

            tree_label = DataCycleCore::ClassificationTreeLabel.find_or_create_by(
              external_source_id: utility_object.external_source.id,
              name: classification_data[:tree_name]
            )

            DataCycleCore::ClassificationTree.create!(
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
      end
    end
  end
end
