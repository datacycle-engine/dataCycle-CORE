# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctions
        extend ImportFunctionsHelper
        extend ImportFunctionsDataHelper
        extend ImportClassifications
        extend Extensions::ImportConcepts

        def self.import_contents(utility_object:, iterator:, data_processor:, options:)
          if options&.dig(:iteration_strategy).blank?
            import_sequential(utility_object:, iterator:, data_processor:, options:)
          else
            send(options.dig(:iteration_strategy), utility_object:, iterator:, data_processor:, options:)
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
                total = 0
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
                      from = [options[:min_count] || 0, 0].max
                      to = [options[:max_count] || total, total].min
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
                            utility_object:,
                            raw_data: content[:dump][locale],
                            locale:,
                            options:
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
                              utility_object:,
                              raw_data: content[:dump][locale],
                              locale:,
                              options:
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
                  if $CHILD_STATUS.present? && $CHILD_STATUS.exitstatus&.zero? || total.zero?
                    logging.phase_finished("#{importer_name}(#{phase_name}) #{locale}", item_count.to_s)
                  else
                    logging.info("#{importer_name}(#{phase_name}) #{locale} (#{item_count} items) aborted")
                    raise DataCycleCore::Generic::Common::Error::ImporterError, "error importing data from #{utility_object.external_source.name} #{importer_name}, #{item_count.to_s.rjust(7)}/#{total}" unless Rails.env.test?
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
                  iterator.call(mongo_item, nil, source_filter).all.no_timeout.max_time_ms(fixnum_max).batch_size(2).each do |content|
                    item_count += 1
                    break if options[:max_count].present? && item_count > options[:max_count]
                    next if options[:min_count].present? && item_count < options[:min_count]

                    data_processor.call(
                      utility_object:,
                      raw_data: content[:dump],
                      locale: nil,
                      options:
                    )

                    next unless (item_count % logging_delta).zero?

                    GC.start

                    times << Time.current

                    logging.info("Imported   #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                  end
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

        def self.aggregate_collection(utility_object, aggregation_function, options)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              download_name = options.dig(:download, :name)
              phase_name = utility_object.source_type.collection_name
              logging.preparing_phase("#{utility_object.external_source.name} #{download_name}")
              logging.phase_started("#{download_name}(#{phase_name})")
              utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                aggregation_function.call(mongo_item, logging, utility_object, options.merge({ download_name:, phase_name: })).to_a
              end
              logging.phase_finished("#{download_name}(#{phase_name})", 0)
            ensure
              logging.phase_finished("#{download_name}(#{phase_name})", 0)
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

                    external_keys = iterate.pluck(:external_id)
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
                        utility_object:,
                        raw_data: content_data,
                        locale:,
                        options:
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
      end
    end
  end
end
