# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Extensions
        module DownloadContentFunctions
          DELTA = 100
          FULL_MODES = DataCycleCore::Generic::DownloadObject::FULL_MODES
          CONFIG_PROPS = [:tree_label, :external_id_prefix, :priority].freeze

          def download_content(download_object:, cleanup_data: nil, credential: nil, iterator: nil, data_id: nil, **keyword_args)
            with_logging(**keyword_args, download_object:, cleanup_data:, credential:, iterator:, data_id:) do |options, step_label|
              locale = options[:locales].first
              item_count = 0
              times = [Time.current]
              credentials = credential.call(download_object.credentials) if credential.present?
              items = items(iterator:, download_object:, options:, locale:)
              items.each_slice(DELTA) do |item_data_slice|
                break if options[:max_count] && item_count >= options[:max_count]

                download_object.source_object.with(download_object.source_type) do |mongo_item|
                  mongo_ids = item_data_slice.map { |item_data| data_id.call(item_data)&.to_s }.compact_blank
                  mongo_items = mongo_item.where(external_id: { '$in' => mongo_ids }).index_by(&:external_id)
                  touch_ids = []

                  item_data_slice.each do |item_data|
                    next if item_data.blank?

                    item_count += 1
                    item_id = data_id.call(item_data)&.to_s
                    item = mongo_items.dig(item_id) || mongo_item.new(external_id: item_id)
                    item.dump ||= {}
                    local_item = item.dump[locale]

                    next unless item_allowed?(local_item:, options:)

                    add_credentials!(item:, download_object:, credentials:) if credentials.present?

                    item_data = cleanup_data.call(item_data) if cleanup_data.present?

                    unless local_item.as_json.eql?(item_data.as_json)
                      item.dump[locale] = item_data
                      item.data_has_changed = true
                    end

                    if item.data_has_changed || item.external_system_has_changed
                      item.save!
                    else
                      touch_ids << item.external_id
                    end
                  end

                  if touch_ids.present?
                    mongo_item
                      .where(external_id: { '$in' => touch_ids })
                      .update_all(seen_at: Time.zone.now)
                  end
                end

                times << Time.current
                download_object.logger.phase_partial(step_label, item_count, times)
              end

              item_count
            end
          end

          def bulk_touch_items(download_object:, options:, iterator: nil, **keyword_args)
            options[:mode] = 'full' # alwas full mode for touch

            with_logging(download_object:, iterator:, options:, **keyword_args) do |opts|
              locale = opts[:locales].first
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                external_keys = items(iterator:, download_object:, options: opts, locale:).to_a.map(&:to_s)
                dump_path = :"dump.#{locale}"

                result = mongo_item.where({
                  dump_path => { '$ne' => nil },
                  external_id: { '$in' => external_keys }
                }).update_all(
                  '$set' => { 'seen_at' => Time.zone.now },
                  '$unset' => {
                    "dump.#{locale}.deleted_at" => true,
                    "dump.#{locale}.last_seen_before_delete" => true,
                    "dump.#{locale}.delete_reason" => true
                  }
                )

                result.modified_count
              end
            end
          end

          def bulk_mark_deleted(download_object:, options:, iterator: nil, **keyword_args)
            options[:mode] = 'full' # alwas full mode for delete

            with_logging(download_object:, iterator:, options:, **keyword_args) do |opts|
              locale = opts[:locales].first
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                external_keys = items(iterator:, download_object:, options: opts, locale:).to_a.map(&:to_s)

                delete_props = {
                  "dump.#{locale}.deleted_at" => Time.zone.now,
                  "dump.#{locale}.last_seen_before_delete" => '$seen_at'
                }
                delete_reason = opts.dig(:download, :delete_reason)
                delete_props["dump.#{locale}.delete_reason"] = delete_reason if delete_reason.present?
                dump_path = :"dump.#{locale}"

                result = mongo_item.where({
                  dump_path => { '$ne' => nil },
                  external_id: { '$in' => external_keys }
                }).update_all(delete_props)

                result.modified_count
              end
            end
          end

          private

          def source_filter(download_object:, options:, locale:)
            I18n.with_locale(locale) do
              source_filter = (options&.dig(:download, :source_filter) || {}).with_indifferent_access
              source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values(binding) }
              last_download = download_object.external_source.last_successful_download
              source_filter[:updated_at] = { '$gte': last_download } if last_download.present? && FULL_MODES.exclude?(options[:mode].to_s)

              source_filter.deep_merge({ "dump.#{locale}.deleted_at": { '$exists': false } })
            end
          end

          def props_from_config(options:)
            options.dig(:download)&.slice(*CONFIG_PROPS)&.stringify_keys || {}
          end

          def endpoint_items(download_object:, options:, locale:)
            endpoint_method = options.dig(:download, :endpoint_method) ||
                              download_object.source_type.collection_name.to_s

            download_object.endpoint(options).send(endpoint_method, lang: locale)
          end

          def iterator_items(iterator:, download_object:, options:, locale:, **keyword_args)
            source_filter = source_filter(download_object:, options:, locale:)

            iterator.call(options:, locale:, source_filter:, download_object:, **keyword_args)
          end

          def items(iterator:, download_object:, options:, locale:)
            if iterator.nil?
              endpoint_items(download_object:, options:, locale:)
            else
              Enumerator.new do |yielder|
                iterator_items(iterator:, download_object:, options:, locale:).each do |item|
                  item.merge!(props_from_config(options:)) if item.is_a?(Hash)
                  yielder << item
                end
              end
            end
          end

          # lower value for priority means higher priority (same as in DelayedJob)
          # default is 5
          def item_allowed?(local_item:, options:)
            step_priority = options.dig(:download, :priority)
            item_priority = local_item&.dig(:priority)

            return true if step_priority.blank? || item_priority.blank?

            step_priority <= item_priority
          end

          def add_credentials!(item:, credentials:)
            return if credentials&.dig('key').blank?

            credential_key = credentials['key']

            return if item.external_system&.dig('credentials', credential_key)&.as_json.eql?(credentials.as_json)

            item.external_system ||= {}
            item.external_system['credentials'] ||= {}
            item.external_system['credentials'][credential_key] = credentials
            item.external_system_has_changed = true
          end

          def iterate_credentials(options:, **keyword_args, &block)
            success = true

            options[:credentials].each_with_index do |credentials, index|
              options = options.merge(credentials_index: index) unless options.key?(:credentials_index) ||
                                                                       options[:credentials].one?
              options = options.merge(credentials:)

              success &&= with_logging(**keyword_args, options:, &block)
            end

            success
          end

          def iterate_read_types(options:, **keyword_args, &block)
            success = true

            options.dig(:download, :read_type).each do |read_type|
              options = options.deep_merge(download: { read_type: })

              success &&= with_logging(**keyword_args, options:, &block)
            end

            success
          end

          def iterate_locales(options:, **keyword_args, &block)
            success = true

            Array.wrap(options[:locales]).each do |language|
              options = options.merge(locales: [language])

              success &&= with_logging(**keyword_args, options:, &block)
            end

            success
          end

          def with_logging(download_object:, options:, iterate_read_types: true, iterate_locales: true, iterate_credentials: true, **keyword_args, &block)
            if options[:credentials].is_a?(::Array) && iterate_credentials
              iterate_credentials(download_object:, options:, iterate_read_types:, iterate_locales:, iterate_credentials:, **keyword_args, &block)
            elsif options.dig(:download, :read_type).is_a?(::Array) && iterate_read_types
              iterate_read_types(download_object:, options:, iterate_read_types:, iterate_locales:, iterate_credentials:, **keyword_args, &block)
            elsif Array.wrap(options[:locales]).many? && iterate_locales
              iterate_locales(download_object:, options:, iterate_read_types:, iterate_locales:, iterate_credentials:, **keyword_args, &block)
            else
              step_label = download_object.step_label(options)
              tstart = Time.current

              init_mongo_db(download_object.database_name) do
                download_object.logger.phase_started(step_label, options.dig(:max_count))

                item_count = yield options, step_label if block

                download_object.logger.phase_finished(step_label, item_count, Time.current - tstart)

                return true
              rescue StandardError => e
                download_object.logger.phase_failed(e, download_object.external_source, step_label)

                return false
              ensure
                GC.start
              end
            end
          end
        end
      end
    end
  end
end
