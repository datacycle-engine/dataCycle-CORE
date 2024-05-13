# frozen_string_literal: true

require 'rake_helpers/parallel_helper'
# require 'hashdiff' # for debugging

module DataCycleCore
  module Generic
    module Common
      module DownloadFunctions
        def self.download_data(download_object:, data_id:, data_name:, modified: nil, delete: nil, iterator: nil, cleanup_data: nil, credential: nil, options:)
          iteration_strategy = options.dig(:download, :iteration_strategy) || options.dig(:iteration_strategy) || :download_sequential
          raise "Unknown :iteration_strategy given: #{iteration_strategy}" unless [:download_sequential, :download_parallel, :download_all, :download_optimized].include?(iteration_strategy.to_sym)
          send(iteration_strategy, download_object:, data_id:, data_name:, modified:, delete:, iterator:, cleanup_data:, credential:, options:)
        end

        def self.download_single(download_object:, data_id:, data_name:, modified: nil, delete: nil, raw_data:, _iterator: nil, cleanup_data: nil, credential: nil, options:)
          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
            init_logging(download_object) do |logging|
              locales = (options.dig(:locales) || options.dig(:download, :locales) || I18n.available_locales).map(&:to_sym)
              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  _credentials = credential.call(download_object.credentials) if credential.present?
                  item_id = data_id.call(raw_data.first[1])
                  item_name = data_name.call(raw_data.first[1])
                  item = mongo_item.find_or_initialize_by('external_id': item_id)
                  item.dump ||= {}
                  raw_data.each do |language, data_hash|
                    next unless locales.include?(language.to_sym)
                    if delete.present?
                      if delete.call(data_hash, language)
                        data_hash['deleted_at'] = item.dump[language].try(:[], 'deleted_at') || Time.zone.now
                        data_hash['delete_reason'] = item.dump[language].try(:[], 'delete_reason') || 'Filtered directly at download. (see delete function in download class.)'
                      else
                        data_hash = data_hash.except('deleted_at', 'delete_reason')
                      end
                    end
                    data_hash[:updated_at] = modified.call(data_hash) if modified.present?
                    item.data_has_changed = true if item.dump.dig(language, 'mark_for_update').present?

                    data_hash = cleanup_data.call(data_hash) if cleanup_data.present?
                    item.data_has_changed ||= diff?(item.dump[language].as_json, data_hash.as_json, diff_base: options.dig(:download, :diff_base))
                    item.dump[language] = data_hash
                  end
                  item.updated_at = modified.call(raw_data.first[1]) if modified.present?
                  item.save!
                  GC.start
                  logging.info("Single download item: #{item_name}", item_id)
                end
              rescue StandardError => e
                ActiveSupport::Notifications.instrument 'download_failed.datacycle', {
                  exception: e,
                  namespace: 'background'
                }

                logging.error(nil, nil, nil, e)
              end
            end
          end
        end

        def self.download_sequential(download_object:, data_id:, data_name:, modified: nil, delete: nil, iterator: nil, cleanup_data: nil, credential: nil, options:)
          success = true
          delta = 100
          options[:locales] ||= I18n.available_locales
          if options[:locales].size != 1
            options[:locales].each do |language|
              success &&= download_sequential(download_object:, data_id:, data_name:, modified:, delete:, iterator:, cleanup_data:, credential:, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
            init_mongo_db(database_name) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                begin
                  download_object.source_object.with(download_object.source_type) do |_mongo_item|
                    max_string = options.dig(:max_count).present? ? (options[:max_count]).to_s : ''
                    logging.phase_started("#{download_object.source_type.collection_name}_#{locale}", max_string)
                    GC.start
                    times = [Time.current]

                    endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
                    items = download_object.endpoint.send(endpoint_method, lang: locale)

                    items.each do |item_data|
                      break if options[:max_count] && item_count >= options[:max_count]

                      item_count += 1
                      next if item_data.nil?

                      item_name = nil
                      item_id = nil
                      init_mongo_db(database_name) do
                        download_object.source_object.with(download_object.source_type) do |mongo_item_parallel|
                          item_id = data_id.call(item_data)
                          item_name = data_name.call(item_data)

                          item = mongo_item_parallel.find_or_initialize_by('external_id': item_id)

                          item.dump ||= {}
                          local_item = item.dump[locale]

                          if options.dig(:download, :restorable).present? && local_item.present?
                            local_item.delete('deleted_at')
                            local_item.delete('delete_reason')
                            local_item.delete('last_seen_before_delete')
                            item.dump[locale] = local_item
                          end

                          if delete.present? && delete.call(item_data, locale)
                            item_data['deleted_at'] = local_item.try(:[], 'deleted_at') || Time.zone.now
                            item_data['delete_reason'] = local_item.try(:[], 'delete_reason') || 'Filtered directly at download. (see delete function in download class.)'
                          end

                          item.data_has_changed = true if options[:mode] == 'full'
                          item.data_has_changed = true if item.dump.dig(locale, 'mark_for_update').present?

                          if item.data_has_changed.nil?
                            last_download = download_object.external_source.last_successful_download
                            if modified.present? && last_download.present?
                              updated_at = modified.call(item_data)
                              item.data_has_changed = updated_at > last_download ? true : nil
                            end
                          end

                          item.data_has_changed = true if options.dig(:download, :skip_diff) == true && item.data_has_changed.nil?
                          item_data = cleanup_data.call(item_data) if cleanup_data.present?
                          item.data_has_changed = diff?(item.dump[locale].as_json, item_data.as_json, diff_base: options.dig(:download, :diff_base)) if item.data_has_changed.nil?

                          if item.data_has_changed
                            # for debugging, also uncomment the require 'hashdiff' at the top of this file
                            # differences = ::Hashdiff.diff(item_data.as_json, item.dump[locale].as_json)
                            item.dump[locale] = item_data
                            item.save!
                          else
                            item.set('seen_at' => Time.zone.now)
                          end
                          logging.item_processed(item_name, item_id, item_count, max_string)
                        end
                      end

                      next unless (item_count % delta).zero?

                      GC.start

                      times << Time.current

                      logging.info("Downloaded #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                    end
                  end
                rescue StandardError => e
                  ActiveSupport::Notifications.instrument 'download_failed.datacycle', {
                    exception: e,
                    namespace: 'background'
                  }

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

        def self.download_optimized(download_object:, data_id:, data_name:, modified: nil, delete: nil, iterator: nil, cleanup_data: nil, credential: nil, options:)
          success = true
          delta = 100
          options[:locales] ||= I18n.available_locales
          if options[:locales].size != 1
            options[:locales].each do |language|
              success &&= download_optimized(download_object:, data_id:, data_name:, modified:, delete:, iterator:, cleanup_data:, credential:, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
            init_mongo_db(database_name) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                begin
                  download_object.source_object.with(download_object.source_type) do |_mongo_item|
                    max_string = options.dig(:max_count).present? ? (options[:max_count]).to_s : ''
                    logging.phase_started("#{download_object.source_type.collection_name}_#{locale}", max_string)
                    GC.start
                    times = [Time.current]

                    endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s

                    credentials = credential.call(download_object.credentials) if credential.present?

                    items = download_object.endpoint.send(endpoint_method, lang: locale)
                    items.each_slice(100) do |item_data_slice|
                      break if options[:max_count] && item_count >= options[:max_count]

                      init_mongo_db(database_name) do
                        download_object.source_object.with(download_object.source_type) do |mongo_item_parallel|
                          mongo_items = mongo_item_parallel
                            .where(external_id: { '$in' => item_data_slice.map { |item_data| data_id.call(item_data) }})
                            .index_by(&:external_id)

                          seen_at = []
                          # update_items = []
                          item_data_slice.each do |item_data|
                            item_count += 1
                            next if item_data.nil?

                            item_id = data_id.call(item_data) || nil
                            item_name = data_name.call(item_data) || nil

                            item = mongo_items.dig(item_id) || mongo_item_parallel.new('external_id': item_id)
                            item.dump ||= {}
                            local_item = item.dump[locale]

                            if options.dig(:download, :restorable).present? && local_item.present?
                              local_item.delete('deleted_at')
                              local_item.delete('delete_reason')
                              local_item.delete('last_seen_before_delete')
                              item.dump[locale] = local_item
                            end

                            if delete.present? && delete.call(item_data, locale)
                              item_data['deleted_at'] = local_item.try(:[], 'deleted_at') || Time.zone.now
                              item_data['delete_reason'] = local_item.try(:[], 'delete_reason') || 'Filtered directly at download. (see delete function in download class.)'
                            end

                            item.data_has_changed = true if options[:mode] == 'full'
                            item.data_has_changed = true if item.dump.dig(locale, 'mark_for_update').present?

                            if item.data_has_changed.nil? && modified.present?
                              last_download = download_object.external_source.last_successful_download
                              if last_download.present?
                                updated_at = modified.call(item_data)
                                item.data_has_changed = updated_at > last_download ? true : nil
                              end
                            end

                            item.data_has_changed = true if options.dig(:download, :skip_diff) == true && item.data_has_changed.nil?
                            item_data = cleanup_data.call(item_data) if cleanup_data.present?
                            item.data_has_changed = diff?(item.dump[locale].as_json, item_data.as_json, diff_base: options.dig(:download, :diff_base)) if item.data_has_changed.nil?

                            # add credential from download_object to item
                            if credentials&.dig('key').present?
                              credential_key = credentials['key']
                              item.external_system ||= {}
                              item.external_system['credentials'] ||= {}
                              if item.external_system.dig('credentials', credential_key).blank? ||
                                 Digest::MD5.hexdigest(item.external_system.dig('credentials', credential_key).to_json) != Digest::MD5.hexdigest(download_object.credentials.to_json)

                                item.external_system['credentials'][credential_key] = download_object.credentials
                                item.save!
                              end
                            end

                            if item.data_has_changed
                              # for debugging, also uncomment the require 'hashdiff' at the top of this file
                              # differences = ::Hashdiff.diff(item_data.as_json, item.dump[locale].as_json)
                              # binding.pry if differences.present?
                              item.dump[locale] = item_data
                              # update_items << item
                              # save only updates seen_at!
                              item.save!
                            else
                              seen_at << item.external_id
                            end
                            logging.item_processed(item_name, item_id, item_count, max_string)
                          end
                          # if update_items.present?
                          #   mongo_item_parallel.collection.delete_many(external_id: { '$in' => update_items.map(&:external_id) })
                          #   mongo_item_parallel.collection.insert_many(update_items.map(&:as_document))
                          # end
                          mongo_item_parallel.where(external_id: { '$in' => seen_at }).update_all(seen_at: Time.zone.now)
                        end
                      end

                      next unless (item_count % delta).zero?

                      times << Time.current

                      logging.info("Downloaded #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                    end
                    GC.start
                  end
                rescue StandardError => e
                  ActiveSupport::Notifications.instrument 'download_failed.datacycle', {
                    exception: e,
                    namespace: 'background'
                  }

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

        def self.download_parallel(download_object:, data_id:, data_name:, modified: nil, delete: nil, iterator: nil, cleanup_data: nil, credential: nil, options:) # rubocop:disable Lint/UnusedMethodArgument
          success = true
          delta = 100

          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
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
                        if delete.present? && delete.call(data_hash, language)
                          data_hash[:deleted_at] = item.dump[language].try(:[], 'deleted_at') || Time.zone.now
                          data_hash[:delete_reason] = item.dump[language].try(:[], 'delete_reason') || 'Filtered directly at download. (see delete function in download class.)'
                          data_hash[:last_seen_before_delete] = item.dump[language].try(:[], 'last_seen_before_delete') if item.dump[language].try(:[], 'last_seen_before_delete').present?
                          data_hash[:archived_at] = item.dump[language].try(:[], 'archived_at') if item.dump[language].try(:[], 'archived_at').present?
                          data_hash[:archive_reason] = item.dump[language].try(:[], 'archive_reason') if item.dump[language].try(:[], 'archive_reason').present?
                          data_hash[:last_seen_before_archived] = item.dump[language].try(:[], 'last_seen_before_archived') if item.dump[language].try(:[], 'last_seen_before_archived').present?
                        end
                        data_hash[:updated_at] = modified.call(data_hash) if modified.present?
                        item.data_has_changed = true if options.dig(:download, :skip_diff) == true || item.dump.dig(language, 'mark_for_update').present?
                        item.data_has_changed = false if modified.present? && modified.call(item_data) < download_object.external_source.last_successful_download

                        data_hash = cleanup_data.call(data_hash) if cleanup_data.present?
                        item.data_has_changed = diff?(item.dump[language].as_json, data_hash.as_json, diff_base: options.dig(:download, :diff_base)) if item.data_has_changed.nil?
                        item.dump[language] = data_hash
                        logging.item_processed(item_name, item_id, item_count, max_string)
                      end
                      item.save!
                    rescue StandardError => e
                      ActiveSupport::Notifications.instrument 'download_failed.datacycle', {
                        exception: e,
                        namespace: 'background'
                      }

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
                ActiveSupport::Notifications.instrument 'download_failed.datacycle', {
                  exception: e,
                  namespace: 'background'
                }

                logging.error(nil, nil, nil, e)
                success = false
              ensure
                logging.phase_finished(download_object.source_type.collection_name.to_s, item_count)
              end
            end
          end
          success
        end

        def self.download_all(download_object:, data_id:, data_name:, modified: nil, delete: nil, cleanup_data: nil, credential: nil, options:, **_unused)
          success = true
          delta = 100

          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
            init_logging(download_object) do |logging|
              locales = (options.dig(:locales) || options.dig(:download, :locales) || I18n.available_locales).map(&:to_sym)

              logging.preparing_phase("#{download_object.external_source.name} #{download_object.source_type.collection_name}")
              item_count = 0

              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  _credentials = credential.call(download_object.credentials) if credential.present?
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

                      item_data.each do |key, data_hash|
                        if locales.include?(key.to_sym)
                          if delete.present? && delete.call(data_hash, key)
                            data_hash[:deleted_at] = item.dump[key].try(:[], 'deleted_at') || Time.zone.now
                            data_hash[:delete_reason] = item.dump[key].try(:[], 'delete_reason') || 'Filtered directly at download. (see delete function in download class.)'
                            data_hash[:last_seen_before_delete] = item.dump[key].try(:[], 'last_seen_before_delete') if item.dump[key].try(:[], 'last_seen_before_delete').present?
                            data_hash[:archived_at] = item.dump[key].try(:[], 'archived_at') if item.dump[key].try(:[], 'archived_at').present?
                            data_hash[:archive_reason] = item.dump[key].try(:[], 'archive_reason') if item.dump[key].try(:[], 'archive_reason').present?
                            data_hash[:last_seen_before_archived] = item.dump[key].try(:[], 'last_seen_before_archived') if item.dump[key].try(:[], 'last_seen_before_archived').present?
                          end
                          data_hash[:updated_at] = modified.call(data_hash) if modified.present?
                          item.data_has_changed = true if options.dig(:download, :skip_diff) == true || item.dump.dig(key, 'mark_for_update').present?
                          item.data_has_changed = false if modified.present? && modified.call(item_data) < download_object.external_source.last_successful_download
                          data_hash = cleanup_data.call(data_hash) if cleanup_data.present?
                          item.data_has_changed = diff?(item.dump[key].as_json, data_hash.as_json, diff_base: options.dig(:download, :diff_base)) if item.data_has_changed.nil?
                          item.dump[key] = data_hash
                        elsif ['included', 'classifications'].include?(key)
                          item.dump[key] = data_hash
                        else
                          next
                        end
                        logging.item_processed(item_name, item_id, item_count, max_string)
                      end
                      item.save!
                    rescue StandardError => e
                      ActiveSupport::Notifications.instrument 'download_failed.datacycle', {
                        exception: e,
                        namespace: 'background'
                      }

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
                ActiveSupport::Notifications.instrument 'download_failed.datacycle', {
                  exception: e,
                  namespace: 'background'
                }

                logging.error(nil, nil, nil, e)
                success = false
              ensure
                logging.phase_finished(download_object.source_type.collection_name.to_s, item_count)
              end
            end
          end
          success
        end

        def self.dump_test_data(download_object:, data_id:, data_name:, raw_data:)
          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
            init_logging(download_object) do |logging|
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                item_id = data_id.call(raw_data.first[1])
                item_name = data_name.call(raw_data.first[1])
                item = mongo_item.find_or_initialize_by('external_id': item_id)
                item.dump = raw_data
                item.save!
                GC.start
                logging.info("Single download_all item #{item_name}", item_id)
              rescue StandardError => e
                ActiveSupport::Notifications.instrument 'dump_failed.datacycle', {
                  exception: e,
                  namespace: 'background'
                }

                logging.error(nil, nil, nil, e)
              end
            end
          end
          true
        end

        def self.dump_raw_data(download_object:, data_id:, data_name:, raw_data:, options:)
          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
            init_logging(download_object) do |logging|
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                locale = options.dig(:download, :locales)&.first || :de
                item_id = data_id.call(raw_data)
                item_name = data_name.call(raw_data)
                item = mongo_item.find_or_initialize_by('external_id': item_id)
                item.dump = { locale => raw_data }
                item.save!
                GC.start
                logging.info("Single download_all item #{item_name}", item_id)
              rescue StandardError => e
                ActiveSupport::Notifications.instrument 'dump_failed.datacycle', {
                  exception: e,
                  namespace: 'background'
                }

                logging.error(nil, nil, nil, e)
              end
            end
          end
          true
        end

        def self.mark_deleted(download_object:, data_id:, options:)
          success = true
          delta = 100
          options[:locales] ||= I18n.available_locales
          deleted_from = download_object.external_source.last_successful_download || Time.zone.local(2010)
          if options[:locales].size != 1
            options[:locales].each do |language|
              success &&= mark_deleted(download_object:, data_id:, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
            init_mongo_db(database_name) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("Mark deleted: #{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                begin
                  download_object.source_object.with(download_object.source_type) do |mongo_item|
                    endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
                    items = download_object.endpoint.send(endpoint_method, lang: locale, deleted_from:)

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
                        item.dump[locale]['last_seen_before_delete'] ||= item.seen_at
                        item.dump[locale]['delete_reason'] ||= options.dig(:download, :delete_reason) if options.dig(:download, :delete_reason).present?
                        item.save!
                        logging.item_processed('delete', item_id, item_count, max_string)
                      rescue StandardError => e
                        ActiveSupport::Notifications.instrument 'mark_deleted_failed.datacycle', {
                          exception: e,
                          namespace: 'background'
                        }

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
                  ActiveSupport::Notifications.instrument 'mark_deleted_failed.datacycle', {
                    exception: e,
                    namespace: 'background'
                  }

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

        def self.mark_deleted_from_data(download_object:, iterator:, archived: nil, options:)
          success = true
          delta = 100
          fixnum_max = (2**(0.size * 4 - 2) - 1)
          options[:locales] ||= I18n.available_locales
          if options[:locales].size != 1
            options[:locales].each do |language|
              success &&= mark_deleted_from_data(download_object:, iterator:, options: options.except(:locales).merge({ locales: [language] }))
            end
          else
            database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
            init_mongo_db(database_name) do
              init_logging(download_object) do |logging|
                locale = options[:locales].first
                logging.preparing_phase("Mark deleted: #{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
                item_count = 0

                source_filter = nil
                I18n.with_locale(locale) do
                  source_filter = options&.dig(:download, :source_filter) || {}
                  source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values }
                end

                GC.start
                times = [Time.current]
                archive_from = options.dig(:download, :archive_from).present? ? eval(options.dig(:download, :archive_from)) : nil # rubocop:disable Security/Eval
                begin
                  download_object.source_object.with(download_object.source_type) do |mongo_item|
                    mongo_item.with_session do |session|
                      if options.dig(:iterator_type) == :aggregate || options.dig(:download, :iterator_type) == 'aggregate'
                        iterate = iterator.call(mongo_item, locale, source_filter)
                      else
                        iterate = iterator.call(mongo_item, locale, source_filter).all.no_timeout.max_time_ms(fixnum_max)
                      end
                      iterate.each do |content|
                        next if archive_from.present? && content.seen_at > archive_from
                        break if options[:max_count].present? && item_count >= options[:max_count]
                        item_count += 1
                        next if options[:min_count].present? && item_count < options[:min_count]

                        session.client.command(refreshSessions: [session.session_id]) # keep the mongo_session alive

                        delete_locales = [locale.to_s]
                        delete_locales = content.dump.keys.map(&:to_s) if options.dig(:download, :delete_all_languages)

                        delete_locales.each do |l|
                          if archived.present? && archived.call(content.dump[l], archive_from)
                            content.dump[l]['archived_at'] ||= Time.zone.now
                            content.dump[l]['last_seen_before_archived'] ||= content.seen_at
                            content.dump[l]['archive_reason'] ||= options.dig(:download, :archive_reason) if options.dig(:download, :archive_reason).present?
                          else
                            content.dump[l]['deleted_at'] ||= Time.zone.now
                            content.dump[l]['last_seen_before_delete'] ||= content.seen_at
                            content.dump[l]['delete_reason'] ||= options.dig(:download, :delete_reason) if options.dig(:download, :delete_reason).present?
                          end
                        end
                        content.keep_seen_at = true
                        content.save!

                        next unless (item_count % delta).zero?

                        GC.start
                        times << Time.current

                        logging.info("Downloaded #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                      end
                    end
                  end
                rescue StandardError => e
                  ActiveSupport::Notifications.instrument 'mark_deleted_failed.datacycle', {
                    exception: e,
                    namespace: 'background'
                  }

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

        def self.mark_updated(download_object:, iterator:, dependent_keys:, options:)
          success = true
          delta = 100
          fixnum_max = (2**(0.size * 4 - 2) - 1)
          locales = (options[:locales] || I18n.available_locales).map(&:to_s)
          deleted_from = download_object.external_source.last_successful_download || Time.zone.local(2010)

          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
            init_logging(download_object) do |logging|
              logging.preparing_phase("Mark Updated: #{download_object.external_source.name} #{download_object.source_type.collection_name} #{locales}")
              item_count = 0

              affected_keys = {}
              endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
              locales.each do |locale|
                affected_keys[locale] = download_object.endpoint.send(endpoint_method, lang: locale, deleted_from:)
              end

              source_filter = options&.dig(:download, :source_filter) || {}
              source_filter = source_filter.with_evaluated_values

              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  if options.dig(:iterator_type) == :aggregate || options.dig(:download, :iterator_type) == 'aggregate'
                    iterate = iterator.call(mongo_item, locales, source_filter)
                  else
                    iterate = iterator.call(mongo_item, locales, source_filter).all.no_timeout.max_time_ms(fixnum_max)
                  end

                  max_string = options.dig(:download, :max_count).to_s
                  logging.phase_started("#{download_object.source_type.collection_name} #{locales}", max_string)

                  GC.start

                  times = [Time.current]

                  iterate.each do |item|
                    affected = false
                    item.dump.each_key do |locale|
                      next unless locales.include?(locale)
                      next if item.nil? || item.dump[locale].blank?
                      next if item.dump[locale]['deleted_at'].present? || item.dump[locale]['archived_at'].present?
                      break if options[:max_count].present? && item_count >= options[:max_count]
                      next if options[:min_count].present? && item_count < options[:min_count]

                      embedded_keys = dependent_keys.call(item.dump[locale])
                      next unless affected_keys[locale].intersect?(embedded_keys) # have an empty intersection --> item is not affected

                      item.dump[locale]['mark_for_update'] = Time.zone.now
                      item.save!
                      logging.item_processed('mark_update', item.external_id, item_count, max_string)

                      affected = true
                      item_count += 1
                      logging.info("modified(#{locale}) #{download_object.source_type.collection_name}: #{item.external_id} -> #{affected_keys[locale] & embedded_keys}")
                      next unless (item_count % delta).zero?
                      GC.start
                      times << Time.current
                      logging.info("Marked #{item_count.to_s.rjust(7)} items in #{GenericObject.format_float((times[-1] - times[0]), 6, 3)} seconds", "ðt: #{GenericObject.format_float((times[-1] - times[-2]), 6, 3)}")
                    end
                  end
                rescue StandardError => e
                  ActiveSupport::Notifications.instrument 'mark_updated_failed.datacycle', {
                    exception: e,
                    namespace: 'background'
                  }

                  logging.error(nil, nil, nil, e)
                  success = false
                ensure
                  logging.phase_finished("#{download_object.source_type.collection_name} #{locales}", item_count)
                end
              end
            end
          end
          success
        end

        def self.bulk_touch_items(download_object:, iterator:, options:)
          success = true
          locale = I18n.available_locales.first.to_s
          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
            init_logging(download_object) do |logging|
              logging.preparing_phase("Touch: #{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")
              endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
              external_keys = download_object.endpoint.send(endpoint_method, lang: locale)
              source_filter = options&.dig(:download, :source_filter) || {}
              source_filter = source_filter.with_evaluated_values

              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  collection = iterator.call(mongo_item, locale, source_filter, external_keys)

                  result = collection.update_all(
                    '$set' => { 'seen_at' => Time.zone.now },
                    '$unset' => {
                      "dump.#{locale}.deleted_at" => true,
                      "dump.#{locale}.last_seen_before_delete" => true,
                      "dump.#{locale}.delete_reason" => true
                    }
                  )

                  item_count = result.documents.pluck('nModified').sum
                rescue StandardError => e
                  ActiveSupport::Notifications.instrument 'touch_items_failed.datacycle', {
                    exception: e,
                    namespace: 'background'
                  }
                  success = false
                  logging.error(nil, nil, nil, e)
                ensure
                  logging.phase_finished("#{download_object.source_type.collection_name} #{locale}", item_count)
                end
              end
            end
          end
          success
        end

        def self.bulk_mark_deleted_from_data(download_object:, iterator:, options:)
          success = true
          locale = I18n.available_locales.first.to_s
          database_name = "#{download_object.source_type.database_name}_#{download_object.external_source.id}"
          init_mongo_db(database_name) do
            init_logging(download_object) do |logging|
              logging.preparing_phase("Mark Deleted: #{download_object.external_source.name} #{download_object.source_type.collection_name} #{locale}")

              source_filter = options&.dig(:download, :source_filter) || {}
              source_filter = source_filter.with_evaluated_values(binding)

              begin
                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  collection = iterator.call(mongo_item, locale, source_filter)

                  item_count = collection.count
                  delete_props = {
                    "dump.#{locale}.deleted_at" => Time.zone.now,
                    "dump.#{locale}.last_seen_before_delete" => '$seen_at'
                  }
                  delete_props["dump.#{locale}.delete_reason"] = options.dig(:download, :delete_reason) if options.dig(:download, :delete_reason).present?

                  result = collection.update_all(delete_props)
                  item_count = result.documents.pluck('nModified').sum
                rescue StandardError => e
                  ActiveSupport::Notifications.instrument 'bulk_mark_deleted_failed.datacycle', {
                    exception: e,
                    namespace: 'background'
                  }
                  success = false
                  logging.error(nil, nil, nil, e)
                ensure
                  logging.phase_finished("#{download_object.source_type.collection_name} #{locale}", item_count)
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

        def self.init_mongo_db(database_name)
          Mongoid.override_database(database_name)
          yield
        ensure
          Mongoid.override_database(nil)
        end

        def self.bson_to_hash(item)
          return item unless item.is_a?(::Hash)
          Hash[item.to_a.map { |k, v| [k, v.is_a?(::Hash) ? bson_to_hash(v) : (v.is_a?(::Array) ? v.map { |i| bson_to_hash(i) } : v)] }]
        end

        def self.diff?(a, b, _options = {})
          !a.eql?(b)
        end
      end
    end
  end
end
