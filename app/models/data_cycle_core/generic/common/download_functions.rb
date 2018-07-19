# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadFunctions
        def self.download_data(download_object:, data_id:, data_name:, options:)
          iteration_strategy = options.dig(:iteration_strategy) || :download_sequential
          raise "Unknown :iteration_strategy given: #{iteration_strategy}" unless [:download_sequential, :download_parallel].include?(iteration_strategy)
          send(iteration_strategy, download_object: download_object, data_id: data_id, data_name: data_name, options: options)
        end

        def self.download_single(download_object:, data_id:, data_name:, raw_data:, options:)
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
                    item.dump[language] = data_hash
                  end
                  item.save!
                  GC.start
                  logging.info("Single download item: #{item_name}", item_id)
                end
              rescue StandardError => e
                logging.error(nil, nil, nil, e)
              end
            end
          end
        end

        def self.download_sequential(download_object:, data_id:, data_name:, options:)
          delta = 100
          options[:locales] ||= I18n.available_locales

          if options[:locales].size != 1
            options[:locales].each do |language|
              download_sequential(download_object: download_object, data_id: data_id, data_name: data_name, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            init_mongo_db(download_object) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                begin
                  download_object.source_object.with(download_object.source_type) do |mongo_item|
                    items = download_object.endpoint.send(options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s)

                    max_string = options.dig(:max_count).present? ? (options[:max_count]).to_s : ''
                    logging.phase_started("#{download_object.source_type.collection_name}_#{locale}", max_string)
                    durations = []

                    items.each do |item_data|
                      break if options[:max_count] && item_count >= options[:max_count]
                      durations << Benchmark.realtime do
                        item_count += 1
                        next if item_data.nil?

                        begin
                          item_id = data_id.call(item_data)
                          item_name = data_name.call(item_data)

                          item = mongo_item.find_or_initialize_by('external_id': item_id)

                          item.dump ||= {}
                          item.dump[locale] = item_data
                          item.save!
                          logging.item_processed(item_name, item_id, item_count, max_string)
                        rescue StandardError => e
                          logging.error(item_name, item_id, item_data, e)
                        end

                        next unless (item_count % delta).zero?

                        GC.start
                        logging.info("Downloaded #{item_count} items in #{durations.sum.round(6)} seconds", "ðt: #{durations[-(delta + 1)..-1]&.sum&.round(6)}")
                      end
                    end
                  end
                rescue StandardError => e
                  logging.error(nil, nil, nil, e)
                ensure
                  logging.phase_finished("#{download_object.source_type.collection_name}_#{locale}", item_count)
                end
              end
            end
          end
        end

        def self.download_parallel(download_object:, data_id:, data_name:, options:)
          delta = 100

          init_mongo_db(download_object) do
            init_logging(download_object) do |logging|
              locales = (options.dig(:locales) || options.dig(:download, :locales) || I18n.available_locales).map(&:to_sym)

              logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name}")
              item_count = 0

              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  items = download_object.endpoint.send(options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s)

                  max_string = options.dig(:max_count).present? ? (options[:max_count]).to_s : ''
                  logging.phase_started(download_object.source_type.collection_name.to_s, max_string)
                  durations = []

                  items.each do |item_data|
                    break if options[:max_count] && item_count >= options[:max_count]
                    durations << Benchmark.realtime do
                      item_count += 1
                      next if item_data.nil?
                      begin
                        item_id = data_id.call(item_data.first[1])
                        item_name = data_name.call(item_data.first[1])
                        item = mongo_item.find_or_initialize_by('external_id': item_id)
                        item.dump ||= {}

                        item_data.each do |language, data_hash|
                          next unless locales.include?(language.to_sym)
                          item.dump[language] = data_hash
                          logging.item_processed(item_name, item_id, item_count, max_string)
                        end
                        item.save!
                      rescue StandardError => e
                        logging.error(item_name, item_id, item_data, e)
                      end

                      next unless (item_count % delta).zero?

                      GC.start
                      logging.info("Downloaded #{item_count} items in #{durations.sum.round(6)} seconds", "ðt: #{durations[-(delta + 1)..-1]&.sum&.round(6)}")
                    end
                  end
                end
              rescue StandardError => e
                logging.error(nil, nil, nil, e)
              ensure
                logging.phase_finished(download_object.source_type.collection_name.to_s, item_count)
              end
            end
          end
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
      end
    end
  end
end
