# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctions
        extend ImportFunctionsHelper
        extend ImportFunctionsDataHelper
        extend ImportClassifications
        extend Extensions::ImportConcepts
        extend ImportData

        def self.import_contents(utility_object:, iterator:, data_processor:, options:)
          if options&.dig(:iteration_strategy).blank?
            import_sequential(utility_object:, iterator:, data_processor:, options:)
          else
            send(options[:iteration_strategy], utility_object:, iterator:, data_processor:, options:)
          end
        end

        def self.import_sequential(utility_object:, iterator:, data_processor:, options:)
          last_ext_key = nil

          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              importer_name = options.dig(:import, :name)

              each_locale(utility_object.locales) do |locale|
                item_count = 0
                total = 0
                step_label = utility_object.step_label(options.merge({ locales: [locale] }))

                begin
                  logging.phase_started(step_label)

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    filter_object = Import::FilterObject.new(options&.dig(:import, :source_filter), locale, mongo_item, binding)
                      .without_deleted
                      .without_archived
                    filter_object = filter_object.with_updated_since(utility_object.external_source.last_successful_try(utility_object.step_name)) if utility_object.mode == :incremental && utility_object.external_source.last_successful_try(utility_object.step_name).present?

                    per = options[:per] || logging_delta
                    aggregate = options[:iterator_type] == :aggregate || options.dig(:import, :iterator_type) == 'aggregate'

                    if aggregate
                      iterate = filtered_items(iterator, locale, filter_object).allow_disk_use(true)
                      page_from = 0
                      page_to = 0
                    else
                      iterate = filtered_items(iterator, locale, filter_object).all.no_timeout.max_time_ms(fixnum_max).batch_size(2)
                      total = iterate.size
                      from = [options[:min_count] || 0, 0].max
                      to = [options[:max_count] || total, total].min
                      page_from = from / per
                      page_to = (to - 1) / per
                    end

                    iterator_proc = lambda { |page|
                      item_count = page * per
                      iterate = iterate.limit(per).offset(page * per) unless aggregate

                      iterate.each do |content|
                        break if options[:max_count].present? && item_count >= options[:max_count]
                        item_count += 1
                        next if options[:min_count].present? && item_count < options[:min_count]
                        last_ext_key = content[:external_id]

                        # access via: to dump, external_system needed to work with reisen_fuer_alle.de - Import (has BSON - Agggregate struct)
                        # content can either be a DataCycleCore::Generic::Collection or a BSON Aggregate, causing an issue when you try to access .dump as method (BSON Aggregate does not provide many functions)
                        raw_data = content[:dump][locale]
                        raw_data['dc_credential_keys'] = content[:external_system]['credential_keys'] if !DataCycleCore::DataHashService.deep_blank?(raw_data) && content[:external_system].present? && content[:external_system]['credential_keys'].present?

                        data_processor.call(
                          utility_object:,
                          raw_data:,
                          locale:,
                          options:
                        )
                      end
                    }

                    times = [Time.current]
                    (page_from..page_to).each do |page|
                      item_count = page * per
                      if Rails.env.test?
                        iterator_proc.call(page)
                        times << Time.current
                        logging.phase_partial(step_label, item_count, times)
                      else
                        read, write = IO.pipe
                        pid = Process.fork do
                          read.close
                          iterator_proc.call(page)
                        rescue StandardError => e
                          full_message = +e.message # unfreeze the string
                          full_message << " occured at '#{e.backtrace&.first}" if e.backtrace.present?
                          full_message << " while trying to import ext. key '#{last_ext_key}'" if last_ext_key.present?

                          error = e.exception(full_message)

                          raise error
                        ensure
                          Marshal.dump(
                            {
                              count: item_count,
                              timestamp: Time.current,
                              error_message: error&.message,
                              error_class: error&.class,
                              error_backtrace: error&.backtrace
                            },
                            write
                          )
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
                          logging.phase_partial(step_label, item_count, times)

                          error = data[:error_class].new(data[:error_message]) if data[:error_class].present?
                          error.set_backtrace(data[:error_backtrace]) if data[:error_backtrace].present?
                        end

                        if $CHILD_STATUS.exitstatus&.positive? || $CHILD_STATUS.exitstatus.blank?
                          raise error if error.present?

                          error_msg = "error importing data from #{utility_object.external_source.name} #{importer_name}, #{item_count.to_s.rjust(7)}/#{total}"
                          raise DataCycleCore::Generic::Common::Error::ImporterError, error_msg
                        end
                      end
                    end
                  end

                  logging.phase_finished(step_label, item_count.to_s)
                rescue StandardError => e
                  logging.phase_failed(e, utility_object.external_source, step_label, 'import_failed.datacycle')
                  raise
                end
              end
            end
          end
        end

        def self.import_all(utility_object:, iterator:, data_processor:, options:)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              step_label = utility_object.step_label(options.merge({ locales: ['all'] }))
              item_count = 0

              begin
                logging.phase_started(step_label)
                times = [Time.current]

                utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                  filter_object = Import::FilterObject.new(options&.dig(:import, :source_filter), nil, mongo_item, binding)
                    .without_deleted
                  filter_object = filter_object.with_updated_since(utility_object.external_source.last_successful_try(utility_object.step_name)) if utility_object.mode == :incremental && utility_object.external_source.last_successful_try(utility_object.step_name).present?

                  filtered_items(iterator, nil, filter_object).all.no_timeout.max_time_ms(fixnum_max).batch_size(2).each do |content|
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
                    logging.phase_partial(step_label, item_count, times)
                  end
                ensure
                  logging.phase_finished(step_label, item_count)
                end
              end
            end
          end
        end

        def self.aggregate_to_collection(utility_object:, iterator:, options:)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              step_label = utility_object.step_label(options)
              output_collection = options.dig(:import, :output_collection)

              item_count = 0
              begin
                logging.phase_started(step_label)

                utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                  mongo_item.with_session do |_session|
                    iterate = iterator.call(mongo_item, utility_object.locales, output_collection).to_a
                    item_count += 1

                    logging.info(step_label, "Aggregate collection \"#{output_collection}\" created for languages #{utility_object.locales}, #{iterate}")
                  end
                end
              ensure
                logging.phase_finished(step_label, item_count)
                GC.start
              end
            end
          end
        end

        def self.aggregate_collection(utility_object, aggregation_function, options)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              download_name = options.dig(:download, :name)
              phase_name = utility_object.source_type.collection_name
              step_label = utility_object.step_label(options)

              logging.phase_started(step_label)
              utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                aggregation_function.call(mongo_item, logging, utility_object, options.merge({ download_name:, phase_name: })).to_a
              end
            ensure
              logging.phase_finished(step_label, 0)
              GC.start
            end
          end
        end

        def self.import_paging(utility_object:, iterator:, data_processor:, options:)
          init_logging(utility_object) do |logging|
            init_mongo_db(utility_object) do
              each_locale(utility_object.locales) do |locale|
                step_label = utility_object.step_label(options.merge({ locales: [locale] }))
                item_count = 0

                begin
                  logging.phase_started(step_label)
                  times = [Time.current]

                  utility_object.source_object.with(utility_object.source_type) do |mongo_item|
                    filter_object = Import::FilterObject.new(options&.dig(:import, :source_filter), locale, mongo_item, binding)
                      .without_deleted
                      .without_archived
                    filter_object = filter_object.with_updated_since(utility_object.external_source.last_successful_try(utility_object.step_name)) if utility_object.mode == :incremental && utility_object.external_source.last_successful_try(utility_object.step_name).present?

                    iterate = filtered_items(iterator, locale, filter_object)
                    iterate = iterate.all.no_timeout.max_time_ms(fixnum_max) unless options[:iterator_type] == :aggregate || options.dig(:import, :iterator_type) == 'aggregate'

                    external_keys = iterate.pluck(:external_id)
                    min = (options[:min_count] || 1) - 1
                    max = (options[:max_count] || external_keys.size) - 1
                    keys = external_keys[min..max]

                    keys.each do |external_id|
                      item_count += 1

                      nested_filter_object = filter_object.with_external_id(external_id)
                      query = filtered_items(iterator, locale, nested_filter_object)
                      query = query.all.no_timeout.max_time_ms(fixnum_max) unless options[:iterator_type] == :aggregate || options.dig(:import, :iterator_type) == 'aggregate'

                      content_data = query.first[:dump][locale]
                      data_processor.call(
                        utility_object:,
                        raw_data: content_data,
                        locale:,
                        options:
                      )

                      times << Time.current
                      logging.phase_partial(step_label, item_count, times, external_id)

                      next unless (item_count % 10).zero?
                      GC.start
                    end
                  end
                ensure
                  logging.phase_finished(step_label, item_count)
                end
              end
            end
          end
        end

        def self.logging_without_mongo(utility_object:, data_processor:, options:)
          init_logging(utility_object) do |logging|
            items_count = 0
            step_label = utility_object.step_label(options)

            begin
              logging.phase_started(step_label)
              items_count = data_processor.call(utility_object, options)
            ensure
              logging.phase_finished(step_label, items_count)
            end
          end
        end
      end
    end
  end
end
