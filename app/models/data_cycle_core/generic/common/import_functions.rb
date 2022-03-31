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
            content = DataCycleCore::Thing.new(
              local_import: true
            )
          else
            # try to find already present content:
            content = DataCycleCore::Thing.by_external_key(utility_object.external_source.id, data['external_key']).first
            if content.blank? && data['external_system_data'].present?
              data['external_system_data'].each do |external_system_entry|
                external_system = DataCycleCore::ExternalSystem.find_by(identifier: external_system_entry['identifier'] || external_system_entry['name'])
                next if external_system.blank?
                next if external_system_entry['external_key'].blank?
                content ||= DataCycleCore::Thing.by_external_key(external_system&.id, external_system_entry['external_key']).first
              end
            end

            # add external_system_syncs where necessary and return
            if content.present?
              present_external_systems = content.view_all_external_data
              all_imported_external_system_data = data['external_system_data'] || []
              all_imported_external_system_data += [{
                'external_key' => data['external_key'],
                'name' => utility_object.external_source.name,
                'identifier' => utility_object.external_source.identifier,
                'last_sync_at' => data.dig('updated_at'),
                'last_successful_sync_at' => data.dig('updated_at')
              }]
              all_imported_external_system_data.each do |es|
                next if present_external_systems.detect { |i| i['external_identifier'] == (es['identifier'] || es['name']) && i['external_key'] == es['external_key'] }.present?
                external_system =
                  if es['identifier'].present?
                    DataCycleCore::ExternalSystem.find_by(identifier: es['identifier'])
                  else
                    DataCycleCore::ExternalSystem.find_by(identifier: es['name']) || DataCycleCore::ExternalSystem.find_by(name: es['name'])
                  end
                external_system = DataCycleCore::ExternalSystem.create!(name: es['name'] || es['identifier'], identifier: es['identifier'] || es['name']) if external_system.blank?
                sync_data = content.add_external_system_data(external_system, { external_key: es['external_key'] }, es['status'] || 'success', 'duplicate', es['external_key'], false)
                update_data = { last_sync_at: es['last_sync_at'], last_successful_sync_at: es['last_successful_sync_at'] }.compact
                sync_data.update(update_data) if update_data.present?
              end

              return content if content&.external_source_id != utility_object.external_source.id || content&.external_key != data['external_key']
            end

            # no content found anywhere --> create new thing
            content ||= DataCycleCore::Thing.new(
              external_source_id: utility_object.external_source.id,
              external_key: data['external_key']
            )
          end

          created = false
          content.webhook_source = utility_object&.external_source&.name

          if content.new_record?
            content.metadata ||= {}
            content.schema = template.schema
            content.template_name = template.template_name
            content.created_by = data['created_by']
            created = true
            content.save!
          end

          global_attributes = {}
          (content.global_property_names + DataCycleCore::Feature::OverlayAttributeService.call(content)).each do |attribute|
            global_attributes[attribute] = content.attribute_to_h(attribute).presence if content.respond_to?(attribute)
          end

          global_data = global_attributes.merge(data)
          global_data = global_data.except('external_key') unless created

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

          current_user = data['updated_by'].present? ? DataCycleCore::User.find_by(id: data['updated_by']) : nil
          invalidate_related_cache = utility_object.external_source.default_options&.fetch('invalidate_related_cache', true)
          partial_update_improved = utility_object.external_source.default_options&.fetch('partial_update_improved', DataCycleCore.partial_update_improved) && !created

          valid = content.set_data_hash(
            data_hash: normalized_data,
            prevent_history: !utility_object.history,
            update_search_all: true,
            current_user: current_user,
            partial_update: !created,
            partial_update_improved: partial_update_improved,
            new_content: created,
            invalidate_related_cache: invalidate_related_cache
          )

          if valid
            Appsignal.increment_counter(
              "import.#{utility_object.external_source.identifier}.#{utility_object.source_type.collection_name}.counts.success",
              1,
              template_name: content.template_name
            )
          else
            Appsignal.increment_counter(
              "import.#{utility_object.external_source.identifier}.#{utility_object.source_type.collection_name}.counts.failure",
              1,
              template_name: content.template_name
            )

            utility_object.logging&.error('Validating import data', data['external_key'], data, content.errors.messages.collect { |k, v| "#{k} #{v&.join(', ')}" }.join(', '))

            content.destroy_content(save_history: false) if created
            return
          end

          data.dig('external_system_data')&.each do |es|
            external_system =
              if es['identifier'].present?
                DataCycleCore::ExternalSystem.find_by(identifier: es['identifier'])
              else
                DataCycleCore::ExternalSystem.find_by(identifier: es['name']) || DataCycleCore::ExternalSystem.find_by(name: es['name'])
              end
            external_system = DataCycleCore::ExternalSystem.create!(name: es['name'] || es['identifier'], identifier: es['identifier'] || es['name']) if external_system.blank?
            sync_data = content.add_external_system_data(external_system, { external_key: es['external_key'] }, es['status'] || 'success', es['sync_type'] || 'export', es['external_key'], es['external_key'].present?)
            update_data = { last_sync_at: es['last_sync_at'], last_successful_sync_at: es['last_successful_sync_at'] }.compact
            sync_data.update(update_data) if update_data.present?
          end

          content
        end

        def self.import_contents(utility_object:, iterator:, data_processor:, options:)
          if options&.dig(:iteration_strategy).blank?
            import_sequential(utility_object: utility_object, iterator: iterator, data_processor: data_processor, options: options)
          else
            send(options.dig(:iteration_strategy), utility_object: utility_object, iterator: iterator, data_processor: data_processor, options: options)
          end
        end

        def self.import_sequential(utility_object:, iterator:, data_processor:, options:)
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
                  source_filter = source_filter.merge({ "dump.#{locale}.deleted_at" => { '$exists' => false }, "dump.#{locale}.archived_at" => { '$exists' => false } })
                  if utility_object.mode == :incremental && utility_object.external_source.last_successful_import.present?
                    source_filter = source_filter.merge({
                      '$or' => [{
                        'updated_at' => { '$gte' => utility_object.external_source.last_successful_import }
                      }, {
                        "dump.#{locale}.updated_at" => { '$gte' => utility_object.external_source.last_successful_import }
                      }]
                    })
                  end

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    per = options[:per] || logging_delta
                    aggregate = options.dig(:iterator_type) == :aggregate || options.dig(:import, :iterator_type) == 'aggregate'

                    if aggregate
                      iterate = iterator.call(mongo_item, locale, source_filter).allow_disk_use(true)

                      page_from = 0
                      page_to = 0
                    else
                      iterate = iterator.call(mongo_item, locale, source_filter).all.no_timeout.max_time_ms(fixnum_max).batch_size(2)

                      total = iterate.size
                      from = options[:min_count] || 0
                      to = options[:max_count] || total
                      page_from = from / per
                      page_to = (to - 1) / per
                    end

                    times = [Time.current]
                    (page_from..page_to).each do |page|
                      item_count = page * per
                      if Rails.env.test?
                        iterate = iterate.limit(per).offset(page * per) unless aggregate
                        iterate.each do |content|
                          break if options[:max_count].present? && item_count >= options[:max_count]
                          item_count += 1
                          next if options[:min_count].present? && item_count < options[:min_count]

                          data_processor.call(
                            utility_object: utility_object,
                            raw_data: content[:dump][locale],
                            locale: locale,
                            options: options
                          )
                        end
                        times << Time.current
                        logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                      else
                        read, write = IO.pipe
                        pid = Process.fork do
                          read.close
                          iterate = iterate.limit(per).offset(page * per) unless aggregate
                          iterate.each do |content|
                            break if options[:max_count].present? && item_count >= options[:max_count]
                            item_count += 1
                            next if options[:min_count].present? && item_count < options[:min_count]

                            data_processor.call(
                              utility_object: utility_object,
                              raw_data: content[:dump][locale],
                              locale: locale,
                              options: options
                            )
                          end
                        rescue StandardError => e
                          logging.info("E: #{e.message}")
                          e.backtrace.each do |line|
                            logging.info("E: #{line}")
                          end
                          raise e.exception
                        ensure
                          Marshal.dump({ count: item_count, timestamp: Time.current }, write)
                          write.close
                        end
                        write.close
                        result = read.read
                        Process.waitpid(pid)
                        read.close
                        if result.size.positive?
                          data = Marshal.load(result) # rubocop:disable Security/MarshalLoad
                          item_count = data[:count]
                          times << data[:timestamp]
                          logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                        end
                        raise DataCycleCore::Generic::Common::Error::ImporterError, "error importing data from #{utility_object.external_source.name} #{importer_name}, #{item_count.to_s.rjust(7)}/#{total}" if $CHILD_STATUS.exitstatus&.positive? || $CHILD_STATUS.exitstatus.blank?
                      end
                    end
                  end
                ensure
                  if $CHILD_STATUS.exitstatus&.zero?
                    logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count.to_s)
                  else
                    logging.info("#{importer_name}(#{phase_name}) #{locale} (#{item_count} items) aborted")
                  end
                end
              end
            end
          end
        end

        def self.import_all(utility_object:, iterator:, data_processor:, options:)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              importer_name = options.dig(:import, :name)
              phase_name = utility_object.source_type.collection_name
              logging.preparing_phase("#{utility_object.external_source.name} #{importer_name}")

              item_count = 0
              begin
                logging.phase_started("#{importer_name}(#{phase_name})")
                source_filter = options&.dig(:import, :source_filter) || {}
                source_filter = source_filter.with_evaluated_values
                source_filter = source_filter.merge({ 'dump.deleted_at' => { '$exists' => false } })
                if utility_object.mode == :incremental && utility_object.external_source.last_successful_import.present?
                  source_filter = source_filter.merge({
                    '$or' => [{
                      'updated_at' => { '$gte' => utility_object.external_source.last_successful_import }
                    }]
                  })
                end

                GC.start

                times = [Time.current]
                utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                  # mongo_item.with_session do |session|
                  iterator.call(mongo_item, nil, source_filter).all.no_timeout.max_time_ms(fixnum_max).each do |content|
                    item_count += 1
                    break if options[:max_count].present? && item_count > options[:max_count]
                    next if options[:min_count].present? && item_count < options[:min_count]

                    # session.client.command(refreshSessions: [session.session_id]) # keep the mongo_session alive

                    data_processor.call(
                      utility_object: utility_object,
                      raw_data: content[:dump],
                      locale: nil,
                      options: options
                    )

                    next unless (item_count % logging_delta).zero?

                    GC.start

                    times << Time.current

                    logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                  end
                  # end
                ensure
                  logging.phase_finished("#{importer_name}(#{phase_name})", item_count)
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

        def self.import_paging(utility_object:, iterator:, data_processor:, options:)
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
                  source_filter = source_filter.merge({ "dump.#{locale}.deleted_at" => { '$exists' => false }, "dump.#{locale}.archived_at" => { '$exists' => false } })
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
                    if options.dig(:iterator_type) == :aggregate || options.dig(:import, :iterator_type) == 'aggregate'
                      iterate = iterator.call(mongo_item, locale, source_filter)
                    else
                      iterate = iterator.call(mongo_item, locale, source_filter).all.no_timeout.max_time_ms(fixnum_max)
                    end

                    external_keys = iterate.map { |c| c[:external_id] }
                    min = (options[:min_count] || 1) - 1
                    max = (options[:max_count] || external_keys.size) - 1
                    keys = external_keys[min..max]

                    keys.each do |external_id|
                      item_count += 1

                      if options.dig(:iterator_type) == :aggregate || options.dig(:import, :iterator_type) == 'aggregate'
                        query = iterator.call(mongo_item, locale, source_filter.merge('external_id' => external_id))
                      else
                        query = iterator.call(mongo_item, locale, source_filter.merge('external_id' => external_id)).all.no_timeout.max_time_ms(fixnum_max)
                      end

                      content_data = query.first[:dump][locale]
                      data_processor.call(
                        utility_object: utility_object,
                        raw_data: content_data,
                        locale: locale,
                        options: options
                      )

                      times << Time.current

                      logging.info("Imported    #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)} | #{external_id}")

                      next unless (item_count % 10).zero?
                      GC.start
                    end
                  end
                ensure
                  logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count)
                end
              end
            end
          end
        end

        def self.logging_without_mongo(utility_object:, data_processor:, options:)
          importer_name = options.dig(:import, :name)
          init_logging(utility_object) do |logging|
            logging.preparing_phase("#{utility_object.external_source.name} #{importer_name}")
            items_count = 0
            begin
              items_count = data_processor.call(utility_object, options)
            ensure
              logging.phase_finished(importer_name, items_count)
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

        def self.fixnum_max
          (2**(0.size * 4 - 2) - 1)
        end

        def self.logging_delta
          @logging_delta ||= 100
        end
      end
    end
  end
end
