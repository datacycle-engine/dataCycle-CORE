# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Extensions
        module DownloadContentFunctions
          include DumpKeyPolicy

          DELTA = 100
          # Ids per bulk statement. A single $in listing a whole project grows towards mongo's 16 MB
          # limit for a query document, so every bulk statement works in slices.
          SLICE_SIZE = 100_000
          FULL_MODES = DataCycleCore::Generic::DownloadObject::FULL_MODES

          def download_content_all(**keyword_args)
            download_content(iterate_locales: false, **keyword_args)
          end

          def download_content(download_object:, iterator: nil, credential: nil, iterate_locales: true, **keyword_args)
            raise DataCycleCore::Generic::Common::Error::ImporterError, 'DEPRECATED: delete function is not supported anymore, extract logic to seperate delete step' if keyword_args[:delete].present?

            credential ||= default_credential
            with_logging(**keyword_args, download_object:, iterator:, credential:, iterate_locales:) do |options, step_label|
              items = items(iterator:, download_object:, options:, locale: options[:locales].first)
              credential_key = credential.call(options[:credentials]) if credential.present?
              download_in_parallel(**keyword_args, download_object:, items:, options: options.merge(iterate_locales:), step_label:, credential_key:)
            end
          end

          def bulk_touch_items(download_object:, options:, iterator: nil, data_id: nil, **keyword_args)
            download_object.mode = :full
            options[:mode] = 'full' # always full mode for touch

            with_logging(download_object:, iterator:, options:, **keyword_args) do |opts, step_label|
              locale = opts[:locales].first
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                external_keys = external_keys_from(items: items(iterator:, download_object:, options: opts, locale:), data_id:)

                result = touch_and_revive_items(mongo_item:, external_ids: external_keys, locale:)
                download_object.logger.info(step_label, "revived #{result[:revived]} items previously flagged deleted for #{locale}") if result[:revived].positive?

                result[:touched]
              end
            end
          end

          # Marks every id the source still lists as seen and revives those that were flagged deleted for
          # +locale+. Two statements on purpose:
          #   * seen_at is refreshed for every id, regardless of which locale dumps a document carries.
          #     seen_at is document level, so a record that missed a single locale pass (e.g. a content that
          #     only became visible at the source between the de and the en run) would otherwise never be
          #     touched again and the mark_deleted steps would remove it in every language it does have.
          #   * updated_at is bumped only for documents that really carried a delete marker. update_all is a
          #     driver statement that runs no callbacks, so it never maintains Mongoid's timestamps: without
          #     the explicit bump an incremental import never learns about the revival and the content stays
          #     deleted in the database -- while bumping it for every touched document would turn every
          #     incremental import into a full one.
          # Only the delete markers are cleared: archived_at comes from a different decision (the +archived+
          # callable of mark_deleted_from_data, not "the source stopped listing it"), so an archived document
          # that reappears stays archived -- and, its seen_at being refreshed here, it no longer ages out on
          # its own either. Un-archiving is the archiving step's call.
          # Returns the number of +touched+ and +revived+ documents.
          def touch_and_revive_items(mongo_item:, external_ids:, locale:)
            external_ids = Array.wrap(external_ids).filter_map { |k| k.to_s.presence }
            return { touched: 0, revived: 0 } if external_ids.blank?

            now = Time.zone.now
            # symbols, not interpolated strings: those read as a possible injection to brakeman
            delete_marker = :"dump.#{locale}.deleted_at"
            touched = 0
            revived = 0

            external_ids.each_slice(SLICE_SIZE) do |keys_slice|
              selector = { external_id: { '$in' => keys_slice } }

              touched += mongo_item.where(selector).update_all('$set' => { 'seen_at' => now }).modified_count
              revived += mongo_item.where(selector.merge(delete_marker => { '$exists' => true })).update_all(
                '$set' => { 'updated_at' => now },
                '$unset' => {
                  delete_marker => true,
                  :"dump.#{locale}.last_seen_before_delete" => true,
                  :"dump.#{locale}.delete_reason" => true
                }
              ).modified_count
            end

            { touched:, revived: }
          end

          def bulk_mark_deleted(download_object:, options:, iterator: nil, data_id: nil, **keyword_args)
            with_logging(download_object:, iterator:, options:, **keyword_args) do |opts, step_label|
              locale = opts[:locales].first
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                times = [Time.current]
                external_keys = external_keys_from(items: items(iterator:, download_object:, options: opts, locale:), data_id:)
                next 0 if external_keys.blank?

                delete_props = {
                  "dump.#{locale}.deleted_at" => Time.zone.now,
                  # '$seen_at' is a reference to the document's own seen_at. It only resolves in an
                  # aggregation pipeline update, which is why the update below goes through the driver
                  # instead of Mongoid's update_all (that one would store the string verbatim).
                  "dump.#{locale}.last_seen_before_delete" => '$seen_at'
                }
                delete_reason = opts.dig(:download, :delete_reason)
                # wrapped in $literal so a reason starting with $ stays a value instead of becoming a field path
                delete_props["dump.#{locale}.delete_reason"] = { '$literal' => delete_reason } if delete_reason.present?
                count = 0
                condition = {
                  "dump.#{locale}": { '$ne' => nil },
                  "dump.#{locale}.deleted_at": { '$exists' => false }
                }

                external_keys.each_slice(SLICE_SIZE) do |keys_slice|
                  next if keys_slice.blank?

                  condition[:external_id] = { '$in' => keys_slice }
                  result = mongo_item.collection.update_many(mongo_item.where(condition).selector, [{ '$set' => delete_props }])
                  count += result.modified_count
                  times << Time.current
                  download_object.logger.phase_partial(step_label, count, times)
                end

                count
              end
            end
          end

          def download_item_slice(download_object:, item_data_slice:, options:, data_id: nil, data_name: nil, cleanup_data: nil, credential_key: nil, step_label: nil, **_keyword_args)
            return if item_data_slice.blank?

            iterate_locales = options[:iterate_locales]
            locales = Array.wrap(iterate_locales ? options[:locales].first : options[:locales]).map(&:to_s)

            download_object.with_mongodb do
              download_object.source_object.with(download_object.source_type) do |mongo_item|
                mongo_ids = if iterate_locales
                              item_data_slice.map { |item_data| data_id.call(item_data)&.to_s }.compact_blank
                            else
                              item_data_slice.map { |item_data| data_id.call(item_data.values&.first)&.to_s }.compact_blank
                            end

                mongo_items = mongo_item.where(external_id: { '$in' => mongo_ids }).index_by(&:external_id)
                touch_ids = []
                item_data_slice.each do |item_data|
                  loaded_data = item_data
                  item_id = data_id.call(item_data)&.to_s || data_id.call(item_data.values&.first)&.to_s
                  item = mongo_items[item_id] || mongo_item.new(external_id: item_id)
                  item.dump ||= {}

                  locales.each do |locale|
                    local_item = item.dump[locale]
                    item_data = get_item_data(loaded_data, locale, iterate_locales:)
                    strip_internal_keys!(item_data) # before anything of ours is written into it
                    item_data['id'] = item_id if item_data['id'].blank? && item_id.present? # check if item_data['id'].blank? is required, because this skips the external_id_hash_method
                    item_data['name'] = data_name&.call(item_data)&.to_s if item_data['name'].blank?
                    item_data['dc_external_id'] = item_id if item_id.present? # make external_id available under dump.de.dc_external_id

                    next unless item_allowed?(local_item:, options:)

                    harvest_external_system!(item:, item_data:)

                    add_credentials!(item:, credential_key:) if credential_key.present?

                    item_data.merge!(props_from_config(options:)) if item_data.is_a?(Hash)
                    item_data = cleanup_data.call(item_data) if cleanup_data.present?

                    unless local_item.as_json.eql?(item_data.as_json)
                      item.dump[locale] = item_data
                      item.data_has_changed = true
                    end
                  end

                  if item.data_has_changed || item.external_system_has_changed
                    begin
                      item.save!
                    rescue Mongo::Error::MaxBSONSize, Mongo::Error::MaxMessageSize => e
                      # a document this size will never fit, no matter how often the step retries it,
                      # so one of them must not take the whole step down with it
                      download_object.logger.item_failed(e, download_object.external_source, step_label, item.external_id, download_object.step_name)
                      # the stored document keeps its old dump, but it is still listed at the source --
                      # without the touch it ages out into the mark_deleted/archive steps
                      touch_ids << item.external_id if item.persisted?
                    end
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
            end
          end

          def download_in_parallel(download_object:, items:, options:, step_label:, **kw_args)
            item_counts = []
            slice_counts = []
            times = [Time.current]
            queue = []

            items.each do |item_data|
              break if options[:max_count] && item_counts.sum >= options[:max_count]
              next if item_data.blank?

              item_counts << 1
              queue << item_data

              next unless queue.size >= DELTA

              download_item_slice(item_data_slice: queue.shift(DELTA), download_object:, items:, options:, step_label:, **kw_args)
              times << Time.current
              slice_counts << DELTA
              download_object.logger.phase_partial(step_label, slice_counts.sum, times)
            end

            download_item_slice(item_data_slice: queue, download_object:, items:, options:, step_label:, **kw_args)

            item_counts.sum
          end

          protected

          def get_item_data(item_data, locale, iterate_locales: true)
            iterate_locales ? item_data : item_data.stringify_keys[locale.to_s]
          end

          def default_credential
            lambda { |credentials|
              return if credentials.blank? || credentials.is_a?(Array) || credentials['credential_key'].blank?

              credentials['credential_key']
            }
          end

          # Moves a payload-supplied external_system onto the mongo item and out of the dump. It is
          # not in INTERNAL_DUMP_KEYS because it is not merely dropped -- its credential_keys are
          # harvested onto the item first -- but the effect on the dump is the same, and a source
          # shipping a field of that name does lose it here. external_system belongs on the item:
          # the import side reads it as content[:external_system] (ImportFunctions, where it becomes
          # raw_data['dc_credential_keys']), never from inside dump.<locale>.
          #
          # Both key forms are deleted and both are harvested: a BSON::Document normalises the symbol,
          # but a plain Hash from a custom iterator or a webhook payload can carry both at once, where
          # a short-circuiting `||` left the string one in the dump with its credential keys
          # unharvested -- the very bug this method exists for, one key form over. #add_credentials!
          # is additive and skips duplicates, so taking both loses nothing. The Hash guard also covers
          # a source shipping a scalar of that name, which `dig(:external_system, ...)` raised on.
          def harvest_external_system!(item:, item_data:)
            return unless item_data.is_a?(::Hash)

            [item_data.delete(:external_system), item_data.delete('external_system')].each do |data_external_system|
              next unless data_external_system.is_a?(::Hash)

              Array.wrap(data_external_system.to_h.symbolize_keys[:credential_keys])
                .each { |credential_key| add_credentials!(item:, credential_key:) }
            end
          end

          def add_credentials!(item:, credential_key:)
            return if credential_key.blank?

            key = 'credential_keys'

            return if item.external_system&.dig(key)&.include?(credential_key)

            item.external_system ||= {}
            item.external_system[key] ||= []
            item.external_system[key] << credential_key
            item.external_system_has_changed = true
          end

          def source_filter_base(download_object:, options:, locale:)
            I18n.with_locale(locale) do
              source_filter = (options&.dig(:download, :source_filter) || {}).with_indifferent_access
              source_filter = I18n.with_locale(locale) { source_filter.with_evaluated_values(binding) }

              source_filter = source_filter.merge({ 'external_system.credential_keys' => options[:credential_key] }) if options[:credential_key].present?

              source_filter.deep_merge({
                "dump.#{locale}": { '$exists': true },
                "dump.#{locale}.deleted_at": { '$exists': false },
                "dump.#{locale}.archived_at": { '$exists': false }
              }).with_indifferent_access
            end
          end

          private

          def source_filter(download_object:, options:, locale:)
            source_filter = source_filter_base(download_object: download_object, options: options, locale: locale)
            last_download = download_object.last_successful_try
            source_filter[:updated_at] = { '$gte': last_download } if last_download.present? && FULL_MODES.exclude?(options[:mode].to_s)

            source_filter.with_indifferent_access
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
              iterator_items(iterator:, download_object:, options:, locale:)
            end
          end

          # The external_id keys the bulk statements match on. +data_id+ resolves whatever the source yields
          # (a payload hash for the endpoint strategies, a plain id for the from_data ones); a bare id needs
          # no resolution, so it falls back to itself.
          # Payloads that resolve to nothing raise instead of falling back to +to_s+: that stringifies the
          # whole payload into a key nothing matches, so the step would report success while touching or
          # marking not a single document -- and a touch that matches nothing lets its data go stale until
          # the mark_deleted steps remove it (a step whose external_key_path/data_id_path is missing or
          # points at the wrong path did exactly that). Single unresolvable payloads are still skipped,
          # they are source noise rather than a broken step.
          def external_keys_from(items:, data_id: nil)
            items = items.to_a
            keys = items.filter_map do |item|
              key = data_id&.call(item)&.to_s
              key = item.to_s if key.blank? && !item.is_a?(Enumerable)

              key.presence
            end

            raise DataCycleCore::Generic::Common::Error::ImporterError, "no external_id could be derived from any of #{items.size} #{items.first.class} items, check external_key_path/data_id_path of this step" if keys.blank? && items.any?(Enumerable)

            keys
          end

          def iterate_credentials(options:, **keyword_args, &block)
            success = true

            options[:credentials].each_with_index do |credentials, index|
              opts = options
              opts = options.merge(credentials_index: index) unless options.key?(:credentials_index) ||
                                                                    options[:credentials].one?
              opts = opts.merge(credentials:)

              success &&= with_logging(**keyword_args, options: opts, &block)
            end

            success
          end

          def iterate_read_types(options:, **keyword_args, &block)
            success = true

            options.dig(:download, :read_type).each do |read_type|
              opts = options.deep_merge(download: { read_type: })

              success &&= with_logging(**keyword_args, options: opts, &block)
            end

            success
          end

          def iterate_locales(options:, **keyword_args, &block)
            success = true

            Array.wrap(options[:locales]).each do |language|
              opts = options.merge(locales: [language])

              success &&= with_logging(**keyword_args, options: opts, &block)
            end

            keyword_args[:download_object]&.emtpy_item_cache!

            success
          end

          def with_logging(download_object:, options:, iterate_read_types: true, iterate_locales: true, iterate_credentials: true, **keyword_args, &block)
            options.delete(:credentials) unless iterate_credentials

            if options[:credentials].is_a?(::Array) && iterate_credentials
              iterate_credentials(download_object:, options:, iterate_read_types:, iterate_locales:, iterate_credentials:, **keyword_args, &block)
            elsif options.dig(:download, :read_type).is_a?(::Array) && iterate_read_types
              iterate_read_types(download_object:, options:, iterate_read_types:, iterate_locales:, iterate_credentials:, **keyword_args, &block)
            elsif Array.wrap(options[:locales]).many? && iterate_locales
              iterate_locales(download_object:, options:, iterate_read_types:, iterate_locales:, iterate_credentials:, **keyword_args, &block)
            else
              step_label = download_object.step_label(options)
              tstart = Time.current

              download_object.with_mongodb do
                download_object.logger.phase_started(step_label, options[:max_count])

                item_count = yield options, step_label if block

                download_object.logger.phase_finished(step_label, item_count, Time.current - tstart)

                return true
              rescue StandardError => e
                download_object.logger.phase_failed(e, download_object.external_source, step_label, download_object.step_name)

                raise
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
