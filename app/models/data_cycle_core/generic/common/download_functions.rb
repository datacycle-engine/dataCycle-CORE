# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadFunctions
        require 'hashdiff'

        def self.download_data(download_object:, data_id:, data_name:, modified: nil, options:)
          iteration_strategy = options.dig(:iteration_strategy) || :download_sequential
          raise "Unknown :iteration_strategy given: #{iteration_strategy}" unless [:download_sequential, :download_parallel].include?(iteration_strategy)
          send(iteration_strategy, download_object: download_object, data_id: data_id, data_name: data_name, modified: modified, options: options)
        end

        def self.download_single(download_object:, data_id:, data_name:, modified:, raw_data:, options:)
          init_mongo_db(download_object) do
            init_logging(download_object) do |logging|
              locales = (options.dig(:locales) || options.dig(:download, :locales) || I18n.available_locales).map(&:to_sym)
              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  item_id = data_id.call(raw_data.first[1])
                  item_name = data_name.call(raw_data.first[1])
                  item = mongo_item.find_or_initialize_by('external_id': item_id)
                  item.dump ||= {}

                  raw_data.each do |language, data_hash|
                    next unless locales.include?(language.to_sym)
                    item.data_has_changed ||= diff?(bson_to_hash(item.dump[language]), data_hash, diff_base: options.dig(:download, :diff_base))
                    data_hash = data_hash.merge(updated_at: modified.call(data_hash)) if modified.present?
                    item.dump[language] = data_hash
                  end
                  item.updated_at = modified.call(raw_data.first[1]) if modified.present?
                  item.save!
                  GC.start
                  logging.info("Single download item: #{item_name}", item_id)
                end
              rescue StandardError => e
                Appsignal.send_error(e, nil, 'background')
                logging.error(nil, nil, nil, e)
              end
            end
          end
        end

        def self.download_sequential(download_object:, data_id:, data_name:, modified:, options:)
          success = true
          delta = 100
          options[:locales] ||= I18n.available_locales
          if options[:locales].size != 1
            options[:locales].each do |language|
              success &&= download_sequential(download_object: download_object, data_id: data_id, data_name: data_name, modified: modified, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            init_mongo_db(download_object) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                begin
                  download_object.source_object.with(download_object.source_type) do |mongo_item|
                    endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
                    items = download_object.endpoint.send(endpoint_method, lang: locale)

                    max_string = options.dig(:max_count).present? ? (options[:max_count]).to_s : ''
                    logging.phase_started("#{download_object.source_type.collection_name}_#{locale}", max_string)

                    GC.start

                    times = [Time.current]

                    items.each do |item_data|
                      break if options[:max_count] && item_count >= options[:max_count]

                      item_count += 1
                      next if item_data.nil?

                      begin
                        item_id = data_id.call(item_data)
                        item_name = data_name.call(item_data)

                        item = mongo_item.find_or_initialize_by('external_id': item_id)
                        item.dump ||= {}
                        item_data = item_data.merge(updated_at: modified.call(item_data)) if modified.present?
                        item.data_has_changed = true if options.dig(:download, :skip_diff) == true
                        item.data_has_changed = false if modified.present? && download_object.external_source.last_successful_download && modified.call(item_data) < download_object.external_source.last_successful_download
                        item.data_has_changed = diff?(bson_to_hash(item.dump[locale]), item_data, diff_base: options.dig(:download, :diff_base)) if item.data_has_changed.nil?
                        item.dump[locale] = item_data
                        item.save!
                        logging.item_processed(item_name, item_id, item_count, max_string)
                      rescue StandardError => e
                        Appsignal.send_error(e, nil, 'background')
                        logging.error(item_name, item_id, item_data, e)
                        success = false
                      end

                      next unless (item_count % delta).zero?

                      GC.start

                      times << Time.current

                      logging.info("Downloaded #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                    end
                  end
                rescue StandardError => e
                  Appsignal.send_error(e, nil, 'background')
                  logging.error(nil, nil, nil, e)
                  success = false
                ensure
                  logging.phase_finished("#{download_object.source_type.collection_name}_#{locale}", item_count)
                end
              end
            end
          end
          success
        end

        def self.download_parallel(download_object:, data_id:, data_name:, modified:, options:)
          success = true
          delta = 100

          init_mongo_db(download_object) do
            init_logging(download_object) do |logging|
              locales = (options.dig(:locales) || options.dig(:download, :locales) || I18n.available_locales).map(&:to_sym)

              logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name}")
              item_count = 0

              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
                  items = download_object.endpoint.send(endpoint_method)

                  max_string = options.dig(:max_count).present? ? (options[:max_count]).to_s : ''
                  logging.phase_started(download_object.source_type.collection_name.to_s, max_string)

                  GC.start

                  times = [Time.current]

                  items.each do |item_data|
                    break if options[:max_count] && item_count >= options[:max_count]

                    item_count += 1
                    next if item_data.nil?
                    begin
                      item_id = data_id.call(item_data.first[1])
                      item_name = data_name.call(item_data.first[1])
                      item = mongo_item.find_or_initialize_by('external_id': item_id)
                      item.dump ||= {}

                      item_data.each do |language, data_hash|
                        next unless locales.include?(language.to_sym)
                        data_hash = data_hash.merge(updated_at: modified.call(data_hash)) if modified.present?
                        item.data_has_changed = true if options.dig(:download, :skip_diff) == true
                        item.data_has_changed = false if modified.present? && modified.call(item_data) < download_object.external_source.last_successful_download
                        item.data_has_changed = diff?(bson_to_hash(item.dump[language]), data_hash, diff_base: options.dig(:download, :diff_base)) if item.data_has_changed.nil?
                        item.dump[language] = data_hash
                        logging.item_processed(item_name, item_id, item_count, max_string)
                      end
                      item.save!
                    rescue StandardError => e
                      Appsignal.send_error(e, nil, 'background')
                      logging.error(item_name, item_id, item_data, e)
                      success = false
                    end

                    next unless (item_count % delta).zero?

                    GC.start

                    times << Time.current

                    logging.info("Downloaded #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                  end
                end
              rescue StandardError => e
                Appsignal.send_error(e, nil, 'background')
                logging.error(nil, nil, nil, e)
                success = false
              ensure
                logging.phase_finished(download_object.source_type.collection_name.to_s, item_count)
              end
            end
          end
          success
        end

        def self.mark_deleted(download_object:, data_id:, options:)
          success = true
          delta = 100
          options[:locales] ||= I18n.available_locales
          deleted_from = download_object.external_source.last_successful_download || Time.zone.local(2010)
          if options[:locales].size != 1
            options[:locales].each do |language|
              success &&= mark_deleted(download_object: download_object, data_id: data_id, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            init_mongo_db(download_object) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                begin
                  download_object.source_object.with(download_object.source_type) do |mongo_item|
                    endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
                    items = download_object.endpoint.send(endpoint_method, lang: locale, deleted_from: deleted_from)

                    max_string = options.dig(:max_count).present? ? (options[:max_count]).to_s : ''
                    logging.phase_started("#{download_object.source_type.collection_name}_#{locale}", max_string)

                    GC.start

                    times = [Time.current]

                    items.each do |item_data|
                      break if options[:max_count] && item_count >= options[:max_count]

                      item_count += 1
                      next if item_data.nil?

                      begin
                        item_id = data_id.call(item_data)

                        begin
                          item = mongo_item.find_by('external_id': item_id)
                        rescue Mongoid::Errors::DocumentNotFound
                          next
                        end

                        next if item.dump[locale].nil?

                        item.dump[locale]['deleted_at'] ||= Time.zone.now
                        item.save!
                        logging.item_processed('delete', item_id, item_count, max_string)
                      rescue StandardError => e
                        Appsignal.send_error(e, nil, 'background')
                        logging.error('delete', item_id, item_data, e)
                        success = false
                      end

                      next unless (item_count % delta).zero?

                      GC.start

                      times << Time.current

                      logging.info("Downloaded #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                    end
                  end
                rescue StandardError => e
                  Appsignal.send_error(e, nil, 'background')
                  logging.error(nil, nil, nil, e)
                  success = false
                ensure
                  logging.phase_finished("#{download_object.source_type.collection_name}_#{locale}", item_count)
                end
              end
            end
          end
          success
        end

        def self.mark_deleted_from_data(download_object:, iterator:, options:)
          success = true
          delta = 100
          fixnum_max = (2**(0.size * 4 - 2) - 1)
          options[:locales] ||= I18n.available_locales
          if options[:locales].size != 1
            options[:locales].each do |language|
              success &&= mark_deleted(download_object: download_object, data_id: data_id, data_name: data_name, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            init_mongo_db(download_object) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                source_filter = options&.dig(:download, :source_filter) || {}
                source_filter = source_filter.with_evaluated_values
                source_filter = source_filter.merge({ "dump.#{locale}.deleted_at" => { '$exists' => false } })

                GC.start
                times = [Time.current]

                begin
                  download_object.source_object.with(download_object.source_type) do |mongo_item|
                    mongo_item.with_session do |session|
                      if options.dig(:iterator_type) == :aggregate || options.dig(:download, :iterator_type) == 'aggregate'
                        iterate = iterator.call(mongo_item, locale, source_filter)
                      else
                        iterate = iterator.call(mongo_item, locale, source_filter).all.no_timeout.max_time_ms(fixnum_max)
                      end
                      iterate.each do |content|
                        break if options[:max_count].present? && item_count >= options[:max_count]
                        item_count += 1
                        next if options[:min_count].present? && item_count < options[:min_count]

                        session.client.command(refreshSessions: [session.session_id]) # keep the mongo_session alive

                        # process data
                        # content.dump[locale] = content.dump[locale].except('deleted_at')
                        content.dump[locale]['deleted_at'] ||= Time.zone.now
                        content.save!

                        next unless (item_count % delta).zero?

                        GC.start
                        times << Time.current

                        logging.info("Downloaded #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                      end
                    end
                  end
                rescue StandardError => e
                  Appsignal.send_error(e, nil, 'background')
                  logging.error(nil, nil, nil, e)
                  success = false
                ensure
                  logging.phase_finished("#{download_object.source_type.collection_name}_#{locale}", item_count)
                end
              end
            end
          end
          success
        end

        def self.init_logging(download_object)
          logging = download_object.init_logging(:download)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end

        def self.init_mongo_db(download_object)
          Mongoid.override_database("#{download_object.source_type.database_name}_#{download_object.external_source.id}")
          yield
        ensure
          Mongoid.override_database(nil)
        end

        def self.bson_to_hash(item)
          return item unless item.is_a?(::Hash)
          Hash[item.to_a.map { |k, v| [k, v.is_a?(::Hash) ? bson_to_hash(v) : (v.is_a?(::Array) ? v.map { |i| bson_to_hash(i) } : v)] }]
        end

        def self.diff?(a, b, options = {})
          if options[:diff_base] && (a.try(:dig, *options[:diff_base].split('.')) || b.try(:dig, *options[:diff_base].split('.')))
            diff(a.try(:dig, *options[:diff_base].split('.')), b.try(:dig, *options[:diff_base].split('.'))).count.positive?
          else
            diff(a, b).count.positive?
          end
        end

        def self.diff(a, b)
          ::Hashdiff.diff(a, b, { numeric_tolerance: 0.001 })
        end
      end
    end
  end
end
