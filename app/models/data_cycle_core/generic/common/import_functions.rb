# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctions
        # TODO: refactor!!
        def self.import_contents(utility_object:, iterator:, data_processor:, options:)
          around_import(utility_object) do |locale|
            phase_name = utility_object.source_type.collection_name

            item_count = 0
            fixnum_max = (2**(0.size * 4 - 2) - 1)
            begin
              utility_object.logging.phase_started("#{phase_name}_#{locale}")

              durations = []

              utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                iterator.call(mongo_item, locale).all.no_timeout.max_time_ms(fixnum_max).each do |content|
                  durations << Benchmark.realtime do
                    item_count += 1

                    data_processor.call(
                      utility_object: utility_object,
                      raw_data: content[:dump][locale],
                      locale: locale,
                      options: options
                    )

                    next unless (item_count % 10).zero?

                    GC.start
                    utility_object.logging.info("Imported #{item_count} items in #{durations.sum} seconds", nil)
                  end
                  break if options[:max_count].present? && item_count >= options[:max_count]
                end
              end
            ensure
              utility_object.logging.phase_finished("#{phase_name}_#{locale}", item_count)
            end
          end
        end

        def self.around_import(utility_object)
          Mongoid.override_database("#{utility_object.source_type.database_name}_#{utility_object.external_source.id}")
          utility_object.locales.each do |locale|
            yield(locale.to_sym)
          end
        ensure
          Mongoid.override_database(nil)
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

          error = content.set_data_hash(data_hash: (content.get_data_hash || {}).merge(data), prevent_history: true)

          if utility_object.logging && error[:error].present?
            utility_object.logging.error('Validating import data', data['external_key'], data, error[:error].values.flatten.join('\n'))
          elsif error[:error].present?
            raise error[:error].first
          end

          content.tap(&:save!)
        end

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
      end
    end
  end
end
