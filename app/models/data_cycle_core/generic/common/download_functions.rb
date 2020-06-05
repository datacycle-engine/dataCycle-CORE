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
                    data_hash = data_hash.merge(modified: modified.call(data_hash)) if modified.present?
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
                        item.data_has_changed = true if options.dig(:download, :skip_diff) == true
                        item.data_has_changed ||= diff?(bson_to_hash(item.dump[locale]), item_data, diff_base: options.dig(:download, :diff_base))
                        item_data = item_data.merge(updated_at: modified.call(item_data)) if modified.present?
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
                        item.data_has_changed ||= diff?(bson_to_hash(item.dump[language]), data_hash, diff_base: options.dig(:download, :diff_base))
                        data_hash = data_hash.merge(modified: modified.call(data_hash)) if modified.present?
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
