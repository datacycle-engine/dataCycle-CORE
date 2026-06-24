# frozen_string_literal: true

require 'rake_helpers/parallel_helper'
# require 'hashdiff' # for debugging

module DataCycleCore
  module Generic
    module Common
      module DownloadFunctions
        extend Extensions::DownloadContentFunctions

        DELTA = Extensions::DownloadContentFunctions::DELTA
        FULL_MODES = DataCycleCore::Generic::DownloadObject::FULL_MODES
        DOWNLOAD_ALL_STRATEGIES = [:download_all, :download_parallel_all, :download_optimized_all, :download_content_all].freeze
        def self.download_data(download_object:, data_id:, data_name:, options:, modified: nil, delete: nil, iterator: nil, cleanup_data: nil)
          credential = default_credential

          iteration_strategy = options.dig(:download, :iteration_strategy) || options[:iteration_strategy] || :download_content
          iteration_strategy = :download_content if iteration_strategy.to_sym.in?([:download_parallel, :download_optimized]) # legacy support
          iteration_strategy = :download_content_all if iteration_strategy.to_sym.in?([:download_parallel_all, :download_optimized_all])

          raise "Unknown :iteration_strategy given: #{iteration_strategy}" unless [:download_all, :download_content, :download_content_all].include?(iteration_strategy.to_sym)

          send(iteration_strategy, download_object:, data_id:, data_name:, modified:, delete:, iterator:, cleanup_data:, credential:, options:)
        end

        def self.download_single(download_object:, data_id:, data_name:, raw_data:, modified: nil, delete: nil, cleanup_data: nil, credential: nil, **keyword_args)
          with_logging(download_object:, data_id:, data_name:, modified:, delete:, raw_data:, cleanup_data:, iterate_locales: false, **keyword_args) do |options, step_label|
            locales = (options[:locales] || options.dig(:download, :locales) || I18n.available_locales).map(&:to_sym)
            download_object.source_object.with(download_object.source_type) do |mongo_item|
              item_id = data_id.call(raw_data.first[1])
              item_name = data_name.call(raw_data.first[1])
              item = mongo_item.find_or_initialize_by(external_id: item_id)
              item.dump ||= {}

              credential_key = credential.call(options[:credentials]) if credential.present?

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

                add_credentials!(item:, credential_key:) if credential_key.present?

                data_hash = cleanup_data.call(data_hash) if cleanup_data.present?
                item.data_has_changed ||= diff?(item.dump[language].as_json, data_hash.as_json, diff_base: options.dig(:download, :diff_base))
                item.dump[language] = data_hash
              end

              item.updated_at = modified.call(raw_data.first[1]) if modified.present?
              item.save!

              download_object.logger.info(step_label, "Single download item: #{item_name}", item_id)
            end

            1 # item_count
          end
        end

        def self.download_all(download_object:, data_id:, modified: nil, delete: nil, cleanup_data: nil, credential: nil, **keyword_args)
          with_logging(download_object:, data_id:, modified:, delete:, cleanup_data:, credential:, iterate_locales: false, **keyword_args) do |options, step_label|
            locales = (options[:locales] || options.dig(:download, :locales) || I18n.available_locales).map(&:to_sym)
            endpoint_method = nil
            item_count = 0
            credential_key = credential.call(options[:credentials]) if credential.present?

            download_object.source_object.with(download_object.source_type) do |mongo_item|
              endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
              items = download_object.endpoint(options).send(endpoint_method)
              times = [Time.current]

              items.each do |item_data|
                break if options[:max_count] && item_count >= options[:max_count]

                item_count += 1
                next if item_data.nil?

                item_id = data_id.call(item_data.first[1])
                item = mongo_item.find_or_initialize_by(external_id: item_id)
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

                    if data_hash.key?(:external_system)
                      data_credential_keys = Array.wrap(data_hash.dig(:external_system, :credential_keys))
                      data_credential_keys.each { |k| add_credentials!(item:, credential_key: k) }
                      data_hash.delete(:external_system)
                    end

                    add_credentials!(item:, credential_key:) if credential_key.present?

                    item.data_has_changed = nil if item.data_has_changed == false # reset data_has_changed if it was false in previous
                    data_hash[:updated_at] = modified.call(data_hash) if modified.present?
                    item.data_has_changed = true if options.dig(:download, :skip_diff) == true || item.dump.dig(key, 'mark_for_update').present?
                    item.data_has_changed = false if modified.present? && modified.call(item_data) < download_object.last_successful_try
                    data_hash = cleanup_data.call(data_hash) if cleanup_data.present?
                    item.data_has_changed = diff?(item.dump[key].as_json, data_hash.as_json, diff_base: options.dig(:download, :diff_base)) if item.data_has_changed.nil?
                    item.dump[key] = data_hash
                  elsif ['included', 'classifications'].include?(key)
                    item.dump[key] = data_hash
                  else
                    next
                  end
                end

                item.save!

                next unless (item_count % DELTA).zero?

                GC.start

                times << Time.current
                download_object.logger.phase_partial(step_label, item_count, times)
              end
            end

            item_count
          end
        end

        def self.dump_test_data(download_object:, data_id:, data_name:, raw_data:, **keyword_args)
          with_logging(download_object:, data_id:, data_name:, raw_data:, iterate_locales: false, **keyword_args) do |_options, step_label|
            download_object.source_object.with(download_object.source_type) do |mongo_item|
              item_id = data_id.call(raw_data.first[1])
              item_name = data_name.call(raw_data.first[1])
              item = mongo_item.find_or_initialize_by(external_id: item_id)
              item.dump = raw_data
              item.save!

              download_object.logger.info(step_label, "Single download_all item #{item_name}", item_id)
            end

            1 # item_count
          end
        end

        def self.dump_raw_data(download_object:, data_id:, data_name:, raw_data:, **keyword_args)
          with_logging(download_object:, data_id:, data_name:, raw_data:, iterate_locales: false, **keyword_args) do |options, step_label|
            download_object.source_object.with(download_object.source_type) do |mongo_item|
              locale = options.dig(:download, :locales)&.first || :de
              item_id = data_id.call(raw_data)
              item_name = data_name.call(raw_data)
              item = mongo_item.find_or_initialize_by(external_id: item_id)
              item.dump = { locale => raw_data }
              item.save!
              GC.start
              download_object.logger.info(step_label, "Single download_all item #{item_name}", item_id)
            end

            1 # item_count
          end
        end

        def self.mark_deleted(download_object:, data_id:, **keyword_args)
          with_logging(download_object:, data_id:, **keyword_args) do |options, _step_label|
            deleted_from = download_object.last_successful_try || Time.zone.local(2010)
            locale = options[:locales].first
            item_count = 0

            download_object.source_object.with(download_object.source_type) do |mongo_item|
              endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s
              items = download_object.endpoint(options).send(endpoint_method, lang: locale, deleted_from:)

              items.each do |item_data|
                break if options[:max_count] && item_count >= options[:max_count]

                item_count += 1
                next if item_data.nil?

                item_id = data_id.call(item_data)

                begin
                  item = mongo_item.find_by(external_id: item_id)
                rescue Mongoid::Errors::DocumentNotFound
                  next
                end

                next if item.dump[locale].nil?

                item.dump[locale]['deleted_at'] ||= Time.zone.now
                item.dump[locale]['last_seen_before_delete'] ||= item.seen_at
                item.dump[locale]['delete_reason'] ||= options.dig(:download, :delete_reason) if options.dig(:download, :delete_reason).present?
                item.save!

                next unless (item_count % DELTA).zero?

                GC.start
              end
            end

            item_count
          end
        end

        def self.logging_message
          # code here
        end

        def self.mark_deleted_from_data(download_object:, iterator:, archived: nil, **keyword_args)
          with_logging(download_object:, iterator:, archived:, **keyword_args) do |options, _step_label|
            fixnum_max = ((2**((0.size * 4) - 2)) - 1)
            locale = options[:locales].first
            item_count = 0
            source_filter = nil

            I18n.with_locale(locale) do
              raise 'No source_filter given. Marking data deleted without one is dangerous.' if options&.dig(:download, :source_filter).blank?

              source_filter = source_filter_base(download_object:, options:, locale:)

              # last_download = download_object.external_source.last_successful_download
              # source_filter[:seen_at] = { '$gte': last_download } if last_download.present? && FULL_MODES.exclude?(options[:mode].to_s)
            end

            archive_from = options.dig(:download, :archive_from).present? ? eval(options.dig(:download, :archive_from)) : nil # rubocop:disable Security/Eval

            download_object.source_object.with(download_object.source_type) do |mongo_item|
              mongo_item.with_session do |session|
                iterate = if options[:iterator_type] == :aggregate || options.dig(:download, :iterator_type) == 'aggregate'
                            iterator.call(mongo_item, locale, source_filter)
                          else
                            iterator.call(mongo_item, locale, source_filter).all.no_timeout.max_time_ms(fixnum_max)
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

                  next unless (item_count % DELTA).zero?

                  GC.start
                end
              end
            end

            item_count
          end
        end

        def self.mark_updated(download_object:, iterator:, dependent_keys:, **keyword_args)
          with_logging(download_object:, iterator:, dependent_keys:, iterate_locales: false, **keyword_args) do |options, step_label|
            fixnum_max = ((2**((0.size * 4) - 2)) - 1)
            locales = (options[:locales] || I18n.available_locales).map(&:to_s)
            deleted_from = download_object.last_successful_try || Time.zone.local(2010)
            item_count = 0
            affected_keys = {}
            endpoint_method = options.dig(:download, :endpoint_method) || download_object.source_type.collection_name.to_s

            locales.each do |locale|
              affected_keys[locale] = download_object.endpoint(options).send(endpoint_method, lang: locale, deleted_from:)
            end

            source_filter = options&.dig(:download, :source_filter) || {}
            source_filter = source_filter.with_evaluated_values

            download_object.source_object.with(download_object.source_type) do |mongo_item|
              iterate = if options[:iterator_type] == :aggregate || options.dig(:download, :iterator_type) == 'aggregate'
                          iterator.call(mongo_item, locales, source_filter)
                        else
                          iterator.call(mongo_item, locales, source_filter).all.no_timeout.max_time_ms(fixnum_max)
                        end

              iterate.each do |item|
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

                  item_count += 1
                  download_object.logger.info(step_label, "modified: #{item.external_id} -> #{affected_keys[locale] & embedded_keys}")

                  next unless (item_count % DELTA).zero?

                  GC.start
                end
              end
            end

            item_count
          end
        end

        def self.bson_to_hash(item)
          return item unless item.is_a?(::Hash)

          item.to_a.to_h do |k, v|
            [k, if v.is_a?(::Hash)
                  bson_to_hash(v)
                else
                  (v.is_a?(::Array) ? v.map { |i| bson_to_hash(i) } : v)
                end]
          end
        end

        def self.diff?(a, b, _options = {})
          !a.eql?(b)
        end
      end
    end
  end
end
