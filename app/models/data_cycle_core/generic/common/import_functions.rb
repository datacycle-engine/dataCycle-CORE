# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctions
        extend ImportClassifications

        def self.process_step(utility_object:, raw_data:, transformation:, default:, config:)
          template = config&.dig(:template) || default.dig(:template)
          create_or_update_content(
            utility_object: utility_object,
            template: load_template(template),
            data: merge_default_values(
              config,
              transformation.call(raw_data)
            ).with_indifferent_access,
            local: false,
            config: config
          )
        end

        def self.create_or_update_content(utility_object:, template:, data:, local: false, config: {})
          return nil if data.except('external_key', 'locale').blank?

          if local
            content = DataCycleCore::Thing.new
          else
            content = DataCycleCore::Thing.find_or_initialize_by(
              external_source_id: utility_object.external_source.id,
              external_key: data['external_key'],
              template_name: template.template_name, # external_keys are sometime not uniq across datatypes!
              template: false
            )
          end
          content.metadata ||= {}
          content.schema = template.schema
          content.template_name = template.template_name
          content.created_by = data['created_by']
          content.webhook_source = utility_object&.external_source&.name
          content.save!

          global_attributes = {}
          (content.global_property_names + DataCycleCore::Feature::OverlayAttributeService.call(content)).each do |attribute|
            global_attributes[attribute] = content.attribute_to_h(attribute).presence if content.respond_to?(attribute)
          end

          global_data = global_attributes.merge(data)

          if config&.dig(:asset_type).present?
            if utility_object.asset_download
              content.asset&.remove_file!

              if data.dig('binary_file').present? && data.dig('binary_file_name').present?
                tempfile = File.new(Rails.root.join('tmp', data.dig('binary_file_name')), 'w')
                tempfile.binmode
                tempfile.write(data.dig('binary_file'))
                tempfile.close
                asset = config.dig(:asset_type).constantize.new(file: Pathname.new(Rails.root.join('tmp', data.dig('binary_file_name'))).open)
                File.delete(Rails.root.join('tmp', data.dig('binary_file_name')))
              else
                asset = config.dig(:asset_type).constantize.new(remote_file_url: data.dig('remote_file_url'))
              end
              asset.save!
              global_data['asset'] = asset.id
            else
              global_data['asset'] = content&.asset&.id
            end
          end

          if DataCycleCore::Feature::Normalize.enabled?
            normalize_options = {
              id: data['external_key'],
              comment: utility_object.external_source.name
            }
            normalized_data, _diff = utility_object.normalizer.normalize(global_data, template.schema, normalize_options)
          else
            normalized_data = global_data
          end

          current_user = data['updated_by'].present? ? DataCycleCore::User.find(data['updated_by']) : nil
          error = content.set_data_hash(data_hash: normalized_data, prevent_history: !utility_object.history, update_search_all: false, current_user: current_user, partial_update: utility_object.partial_update)

          if utility_object.logging && error[:error].present?
            utility_object.logging.error('Validating import data', data['external_key'], data, error[:error].values.flatten.join('\n'))
          elsif error[:error].present?
            raise error[:error].first
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
          fixnum_max = (2**(0.size * 4 - 2) - 1)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              importer_name = options.dig(:import, :name)
              phase_name = utility_object.source_type.collection_name
              logging.preparing_phase("#{utility_object.external_source.name} #{importer_name}")

              each_locale(utility_object.locales) do |locale|
                item_count = 0
                begin
                  logging.phase_started("#{importer_name}(#{phase_name}) #{locale}")
                  source_filter = options&.dig(:import, :source_filter) || {}
                  source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values }
                  source_filter = source_filter.merge({ "dump.#{locale}.deleted_at" => { '$exists' => false } })
                  if utility_object.mode == :incremental && utility_object.external_source.last_successful_import.present?
                    source_filter = source_filter.merge({
                      '$or' => [{
                        'updated_at' => { '$gte' => utility_object.external_source.last_successful_import }
                      }, {
                        "dump.#{locale}.updated_at" => { '$gte' => utility_object.external_source.last_successful_import }
                      }]
                    })
                  end

                  GC.start

                  times = [Time.current]

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    mongo_item.with_session do |session|
                      if options.dig(:iterator_type) == :aggregate || options.dig(:import, :iterator_type) == 'aggregate'
                        iterate = iterator.call(mongo_item, locale, source_filter)
                      else
                        iterate = iterator.call(mongo_item, locale, source_filter).all.no_timeout.max_time_ms(fixnum_max)
                      end
                      iterate.each do |content|
                        break if options[:max_count].present? && item_count >= options[:max_count]
                        item_count += 1
                        next if options[:min_count].present? && item_count < options[:min_count]

                        session.client.command(refreshSessions: [session.session_id]) # keep the mongo_session alive

                        data_processor.call(
                          utility_object: utility_object,
                          raw_data: content[:dump][locale],
                          locale: locale,
                          options: options
                        )

                        next unless (item_count % delta).zero?

                        GC.start

                        times << Time.current

                        logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                      end
                    end
                  end
                ensure
                  logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count)
                end
              end
            end
          end
        end

        def self.aggregate_to_collection(utility_object:, iterator:, options:)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              importer_name = options.dig(:import, :name)
              phase_name = utility_object.source_type.collection_name
              logging.preparing_phase("#{utility_object.external_source.name} #{importer_name}")
              output_collection = options.dig(:import, :output_collection)

              item_count = 0
              begin
                logging.phase_started("#{importer_name}(#{phase_name})")

                GC.start

                utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                  mongo_item.with_session do |_session|
                    iterate = iterator.call(mongo_item, utility_object.locales, output_collection).to_a
                    item_count += 1

                    logging.info("Aggregate collection \"#{output_collection}\" created for languages #{utility_object.locales}, #{iterate}")
                  end
                end
              ensure
                logging.phase_finished("#{importer_name}(#{phase_name})", item_count)
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

        def self.init_logging(utility_object)
          logging = utility_object.init_logging(:import)
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

        def self.load_template(template_name)
          I18n.with_locale(:de) do
            DataCycleCore::Thing.find_by!(template: true, template_name: template_name)
          end
        rescue ActiveRecord::RecordNotFound
          raise "Missing template #{template_name}"
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
