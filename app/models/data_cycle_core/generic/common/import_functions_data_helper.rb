# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctionsDataHelper
        PROPERTIES_WITH_IMPORTED_FLAG = [
          'data_pool'
        ].freeze

        # Syncs external system data to existing Thing objects without creating or updating content.
        #
        # @param utility_object [Object] the import utility object
        # @param raw_data [Hash] the raw data from the external system
        # @param transformation [Proc] transforms raw data into expected format
        # @param default [Hash] default values to merge
        # @param config [Hash] step-specific configuration
        #
        # @return [DataCycleCore::Thing, nil] the Thing object, or nil if not found or on error
        # @raise [StandardError] re-raises exceptions in local environments
        def process_syncs(utility_object:, raw_data:, transformation:, default:, config:)
          template, data = pre_process_step(utility_object:, raw_data:, transformation:, default:, config:)

          return if DataHashService.deep_blank?(data) ||
                    data['external_key'].blank? ||
                    data['external_system_data'].blank?

          content = find_thing(data:, utility_object:)

          return if content.nil?

          step_config = utility_object.step_config(config)

          content.invalidate_self if add_external_system_data!(content:, data:, step_config:, utility_object:, update: false)

          content
        rescue StandardError => e
          instrument_import_failure(exception: e, utility_object:, data:, raw_data:, template:)
          raise if Rails.env.local?

          nil
        end

        def process_step(utility_object:, raw_data:, transformation:, default:, config:)
          template, data = pre_process_step(utility_object:, raw_data:, transformation:, default:, config:)

          return if DataHashService.deep_blank?(data) || data['external_key'].blank?

          data = post_process_data(data:, config:, utility_object:).slice(*template.importable_property_names)
          transformation_hash = Digest::SHA256.hexdigest(data.to_json)
          external_key = data['external_key']
          external_source_id = utility_object.external_source.id
          external_hash = ExternalHash.find_or_initialize_by(external_key:, external_source_id:, locale: I18n.locale)

          if external_hash.hash_value == transformation_hash && utility_object.mode.to_s != 'reset'
            external_hash.touch(:seen_at)
            Thing.by_external_key(utility_object.external_source.id, data['external_key']).first
          else
            content = create_or_update_content(utility_object:, template:, data:, local: false, config:)
            return content unless content&.persisted? &&
                                  content.external_key == external_key &&
                                  content.external_source_id == external_source_id

            external_hash.hash_value = transformation_hash
            external_hash.seen_at = Time.zone.now
            external_hash.save
            content
          end
        rescue StandardError => e
          instrument_import_failure(exception: e, utility_object:, data:, raw_data:, template:)
          raise if Rails.env.local?

          nil
        end

        # Publishes import failure notification event 'object_import_failed.datacycle'.
        #
        # @param exception [StandardError] the exception that caused the failure
        # @param utility_object [Object] the import utility object
        # @param data [Hash, nil] the processed data
        # @param raw_data [Hash, nil] the original raw data
        # @param template [DataCycleCore::Thing, nil] the template instance
        def instrument_import_failure(exception:, utility_object:, data:, raw_data:, template:)
          ActiveSupport::Notifications.instrument 'object_import_failed.datacycle', {
            exception:,
            namespace: 'importer',
            external_system: utility_object&.external_source,
            item_id: data&.dig('external_key') || raw_data&.dig('id'),
            template_name: template&.template_name
          }
        end

        # Prepares raw data for import by loading template, preprocessing, and transforming.
        #
        # @param utility_object [Object] the import utility object
        # @param raw_data [Hash] the raw data from the external system
        # @param transformation [Proc] transforms raw data into expected format
        # @param default [Hash] default values to merge
        # @param config [Hash] step-specific configuration
        #
        # @return [Array(DataCycleCore::Thing, Hash), nil] template and processed data, or nil if raw_data is blank
        def pre_process_step(utility_object:, raw_data:, transformation:, default:, config:)
          return if DataHashService.deep_blank?(raw_data)

          template = load_template(config&.dig(:template) || default[:template])
          raw_data = pre_process_data(raw_data:, config:, utility_object:)

          return template, merge_default_values(
            config,
            transformation.call(raw_data || {}),
            utility_object
          ).with_indifferent_access
        end

        def create_or_update_content(utility_object:, template:, data:, local: false, config: {}, **)
          return if data.except('external_key', 'locale').blank?

          step_config = utility_object.step_config(config)
          step_label = utility_object.step_label({ locales: [I18n.locale] })
          content = find_or_initialize_content(data:, utility_object:, template:, local:)

          # also updates external system/key if necessary
          unless update_allowed?(content:, utility_object:, data:, step_config:, step_label:)
            add_external_system_data!(content:, data:, step_config:, utility_object:, update: false)
            return content
          end

          if (template_changed = template_changed?(content:, template:))
            previous_template_name = content.template_name

            unless content.can_become?(template, data:)
              raise DataCycleCore::Error::Import::TemplateConversionError.new(
                template_name: content.template_name,
                expected_template_name: template.template_name,
                external_source: utility_object&.external_source,
                external_key: content.external_key,
                validation_errors: content.template_conversion_errors(template, data:)
              )
            end
          end

          created = false
          content.webhook_source = utility_object&.external_source&.name
          external_key = data['external_key']
          current_user = User.find_by(id: data['updated_by']) if data['updated_by'].present?
          invalidate_related_cache = step_config['invalidate_related_cache'] != false
          global_data = nil
          valid = false

          # wrap in transaction to ensure atomicity when creating new content
          # and setting data hash, so that we don't end up with a content that has no
          # data hash set, but is already persisted in the database.
          ActiveRecord::Base.transaction do
            if content.new_record?
              content.metadata ||= {}
              content.created_by = data['created_by']
              created = true
              content.save!
            elsif template_changed
              # STI: the cast returns a NEW instance of the target subclass; the old `content` ref is stale. Reassign.
              content = content.update_template!(target_template: template, data:)
            elsif content.changed?
              content.save!
            end

            # computed after a possible conversion, so local properties reflect the (new) template
            # 'id' is only used to look up existing content (see #find_thing) and is not a writable
            # schema property, so exclude it here (like 'external_key' below) to keep it out of set_data_hash.
            global_data = data.except(*content.local_property_names, 'overlay', 'id')
            add_properties_with_imported_flag!(content, global_data)
            global_data.except!('external_key') unless created

            valid = content.set_data_hash(
              data_hash: global_data,
              prevent_history: !utility_object.history,
              update_search_all: true,
              current_user:,
              new_content: created,
              invalidate_related_cache:
            )

            raise ActiveRecord::Rollback unless valid
          end

          if valid
            instrument_template_conversion(content:, utility_object:, item_id: external_key, previous_template_name:) if template_changed

            ActiveSupport::Notifications.instrument 'object_import_succeeded.datacycle.counter', {
              external_system: utility_object.external_source,
              step_name: utility_object.step_name,
              template_name: content.template_name
            }
          else
            ActiveSupport::Notifications.instrument 'object_import_failed.datacycle.counter', {
              external_system: utility_object.external_source,
              step_name: utility_object.step_name,
              template_name: content.template_name
            }

            errors = content.errors.messages.collect { |k, v| "#{k} #{v&.join(', ')}" }.join(', ')
            error_keys = content.errors.messages.keys.map(&:to_s)
            error_hash = { 'external_key' => external_key }.merge((global_data || {}).slice(*error_keys))
            utility_object.logger.validation_error(step_label, error_hash, errors)

            return
          end

          add_external_system_data!(content:, data:, step_config:, utility_object:, update: true)

          content
        rescue DataCycleCore::Error::Import::TemplateConversionError => e
          ActiveSupport::Notifications.instrument 'object_template_conversion_failed.datacycle', {
            exception: e,
            namespace: 'importer',
            external_system: utility_object&.external_source,
            item_id: data['external_key'],
            template_name: template&.template_name
          }
          content.reload if content&.persisted? # needed to successfully link this content in dc_sync
          content
        rescue IOError # ignore IOErrors from ActiveStorage (seems to be a bug), the file will still be imported
          content.reload if content&.persisted? # needed to successfully link this content in dc_sync
          content
        rescue StandardError => e
          ActiveSupport::Notifications.instrument 'object_import_failed.datacycle', {
            exception: e,
            namespace: 'importer',
            external_system: utility_object&.external_source,
            item_id: data['external_key'],
            template_name: template.template_name
          }
          raise if Rails.env.local?

          content.reload if content&.persisted? # needed to successfully link this content in dc_sync
          content
        end

        def template_changed?(content:, template:)
          content.template_name != template.template_name && !content.new_record?
        end

        def find_thing(data:, utility_object:)
          Thing.first_by_id_or_external_data(
            id: data['id'],
            external_key: data['external_key'],
            external_system: utility_object.external_source,
            external_system_syncs: data['external_system_data']
          )
        end

        def find_or_initialize_content(data:, utility_object:, template:, local:)
          return Thing.new(local_import: true, template_name: template.template_name) if local

          find_thing(data:, utility_object:) || Thing.new(
            external_source_id: utility_object.external_source.id,
            external_key: data['external_key'],
            template_name: template.template_name
          )
        end

        def self_primary?(content:, utility_object:, data:, step_config:)
          psc = full_external_system_data(data, utility_object).detect { |esd| esd['primary'] }
          return false if psc.nil?

          identifier = psc['identifier'] || psc['name']
          return false unless Array.wrap(step_config['current_instance_identifiers']).include?(identifier)
          return true if (content.external_source_id.nil? && content.external_key.nil?) ||
                         content.external_source_id != utility_object.external_source.id

          # restore content to local if current external_source thinks, that this is the primary system
          content.external_source_id = nil
          content.external_key = nil
          data_hash = {}
          add_properties_with_imported_flag!(content, data_hash)
          content.set_data_hash(data_hash:, prevent_history: !utility_object.history)
          content.save!
          true
        end

        def update_allowed?(content:, utility_object:, data:, step_config:, step_label:)
          return true if content.new_record?
          return false if self_primary?(content:, utility_object:, data:, step_config:)

          if content&.external_source_id != utility_object.external_source.id
            return false unless update_primary_system?(content, utility_object.external_source, data['external_key'], step_config)

            change_primary_system!(content:, data:, new_external_source: utility_object.external_source)
          elsif content&.external_key != data['external_key']
            return false unless update_primary_key?(content, data['external_key'])

            content.change_primary_system(utility_object.external_source, data['external_key'])
            utility_object.logger.primary_key_changed(step_label, content, content.external_key_change)
          end

          true
        end

        def instrument_template_conversion(content:, utility_object:, item_id:, previous_template_name:)
          ActiveSupport::Notifications.instrument 'object_template_converted.datacycle', {
            namespace: 'importer',
            external_system: utility_object.external_source,
            step_name: utility_object.step_name,
            item_id:,
            template_name: content.template_name,
            previous_template_name:
          }
        end

        def full_external_system_data(data, utility_object)
          es_data = Array.wrap(data['external_system_data'])
          es_data << {
            'external_key' => data['external_key'],
            'name' => utility_object.external_source.name,
            'identifier' => utility_object.external_source.identifier,
            'sync_type' => 'import',
            'last_sync_at' => data['updated_at'] || Time.zone.now,
            'last_successful_sync_at' => data['updated_at'] || Time.zone.now,
            'status' => 'success'
          }

          es_data
        end

        # Upserts ExternalSystemSync records for the given content.
        #
        # @param content [DataCycleCore::Thing] the content to add the syncs to
        # @param data [Hash] the transformed data containing external_key and external_system_data
        # @param step_config [Hash] the merged step configuration
        # @param utility_object [Object] the import utility object
        # @param update [Boolean] whether syncs for the primary system are allowed to be updated
        #
        # @return [Boolean] true if any syncs were upserted, false otherwise
        def add_external_system_data!(content:, data:, step_config:, utility_object:, update: false) # rubocop:disable Naming/PredicateMethod
          es_data = full_external_system_data(data, utility_object)
          es_upsert = []
          external_systems = ExternalSystem.by_names_or_identifiers(es_data.pluck('identifier', 'name').flatten.compact.uniq)
          external_systems = external_systems.index_by(&:identifier).merge(external_systems.index_by(&:name))
          existing_systems = content.view_all_external_data

          es_data.each do |es|
            identifier = es['identifier'] || es['name']
            name = es['name'] || es['identifier']

            next if Array.wrap(step_config['current_instance_identifiers']).include?(identifier)

            existing_sync = existing_systems.find do |i|
              i['external_identifier'] == identifier &&
                i['external_key'] == es['external_key']
            end
            next if existing_sync && es['sync_type'] != ExternalSystemSync::SYNC_TYPES[:import]

            external_system = external_systems[es['identifier']] || external_systems[es['name']]
            external_system = ExternalSystem.create!(name:, identifier:) if external_system.nil? && !step_config['reject_unknown_external_systems']

            next if external_system.nil?
            next if content.external_source_id == external_system.id && !update
            next if content.external_source_id == external_system.id && content.external_key == es['external_key']

            es_upsert << {
              syncable_type: content.class.base_class.name,
              syncable_id: content.id,
              external_system_id: external_system.id,
              external_key: es['external_key'],
              sync_type: es['sync_type'] || ExternalSystemSync::SYNC_TYPES[:duplicate],
              status: es['status'] || 'success',
              last_sync_at: es['last_sync_at'],
              last_successful_sync_at: es['last_successful_sync_at']
            }
          end

          es_upsert.uniq! { |e| [e[:external_system_id], e[:external_key], e[:sync_type]] }

          return false if es_upsert.blank?

          ExternalSystemSync.upsert_all(
            es_upsert,
            unique_by: :index_external_system_syncs_on_unique_attributes,
            returning: false
          )

          true
        end

        def load_default_values(data_hash)
          return nil if data_hash.blank?

          return_data = {}
          data_hash.each do |key, value|
            return_data[key] = default_classification(**value.symbolize_keys)
          end
          return_data.compact_blank
        end

        def load_template(template_name)
          I18n.with_locale(:de) do
            Thing.new(template_name:)
          end
        end

        def default_classification(value:, tree_label:)
          [
            Classification
              .joins(classification_groups: [{ classification_alias: [{ classification_tree: [:classification_tree_label] }] }])
              .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })&.first&.id
          ].compact_blank
        end

        def merge_default_values(config, data_hash, utility_object)
          new_hash = {}
          new_hash = load_default_values(config[:default_values]) if config&.dig(:default_values).present?
          new_hash.merge!(data_hash)

          new_hash['dc_ext_key_priority'] ||= new_hash['external_key'].priority if new_hash['external_key'].respond_to?(:priority)
          transform_external_system_data!(config, new_hash, utility_object)

          new_hash
        end

        def transform_external_system_data!(config, data_hash, utility_object)
          merged_config = utility_object.step_config(config)
          remove_es_data!(data_hash, utility_object) && return if merged_config['import_external_system_data'].blank?

          return if data_hash['external_system_data'].blank?

          if (mapping = merged_config['external_system_identifier_mapping']).present?
            data_hash['external_system_data'].each do |d|
              d['identifier'] = mapping[d['identifier']] || d['identifier']
            end
          end

          transformation_config = merged_config['external_system_identifier_transformation']

          return unless transformation_config&.key?('module') && transformation_config.key?('method')

          data_hash['external_system_data'].each do |d|
            t_module = transformation_config['module'].safe_constantize
            t_method = transformation_config['method']
            d['identifier'] = t_module.send(t_method, d['identifier'])
          end
        end

        def remove_es_data!(data, utility_object)
          es = utility_object.external_source

          data['external_system_data']&.select! do |d|
            d['identifier'] == es.identifier || d['name'] == es.name
          end
        end

        def pre_process_data(raw_data:, config:, utility_object:)
          return raw_data unless config&.key?(:before)

          whitelist = config.dig(:before, :whitelist)
          raw_data = Transformations::BlacklistWhitelistFunctions.apply_whitelist(raw_data, whitelist) if whitelist.present?
          blacklist = config.dig(:before, :blacklist)
          raw_data = Transformations::BlacklistWhitelistFunctions.apply_blacklist(raw_data, blacklist) if blacklist.present?

          return raw_data if config.dig(:before, :processors).blank?

          Array.wrap(config.dig(:before, :processors)).each do |processor|
            class_name = ModuleService.load_module(processor[:module])

            Array.wrap(processor[:method]).each do |method_name|
              next unless class_name.respond_to?(method_name)

              raw_data = class_name.send(method_name, raw_data, utility_object)
            end
          end

          raw_data
        end

        def post_process_data(data:, config:, utility_object:)
          return data unless config&.key?(:after)

          whitelist = config.dig(:after, :whitelist)
          data = Transformations::BlacklistWhitelistFunctions.apply_whitelist(data, whitelist) if whitelist.present?
          blacklist = config.dig(:after, :blacklist)
          data = Transformations::BlacklistWhitelistFunctions.apply_blacklist(data, blacklist) if blacklist.present?

          return data if config.dig(:after, :processors).blank?

          Array.wrap(config.dig(:after, :processors)).each do |processor|
            class_name = ModuleService.load_module(processor[:module])

            Array.wrap(processor[:method]).each do |method_name|
              next unless class_name.respond_to?(method_name)

              data = class_name.send(method_name, data, utility_object)
            end
          end

          data
        end

        def add_properties_with_imported_flag!(content, data)
          content.properties_with_imported_flag.each do |key|
            data["#{key}_imported"] = data.key?(key)
          end
        end

        def change_primary_system!(content:, data:, new_external_source:)
          content.change_primary_system(new_external_source, data['external_key'])
          data.reverse_merge!(content.resettable_import_property_names.index_with { |_key| nil })
        end

        def fixnum_max
          ((2**((0.size * 4) - 2)) - 1)
        end

        def logging_delta
          @logging_delta ||= 100
        end

        def primary_system_priority_list(config, **)
          case config[:primary_system_priority]
          when Array then config[:primary_system_priority]
          when Hash
            p_module = config.dig(:primary_system_priority, :module)
            p_method = config.dig(:primary_system_priority, :method)
            p_module.safe_constantize&.send(p_method, **)
          end
        end

        def primary_system_index(priority_list, external_system)
          return nil if priority_list.blank? || external_system.nil?

          priority_list.index { |name| external_system.name == name || external_system.identifier == name }
        end

        # false if:
        #   import step not a Hash
        #   there is already a content with this system/key combo or key is blank
        #   priority list is empty
        #   current system is not in priority_list
        #   current system is higher ranked in priority list
        #   new system is not in priority_list
        def update_primary_system?(content, new_external_system, new_external_key, config)
          return false if content.external_source_id == new_external_system.id
          return false unless config.is_a?(Hash)
          return false if new_external_key.blank?

          priority_list = primary_system_priority_list(config, content:, new_external_system:, new_external_key:, config:)

          return false if priority_list.blank?

          current_index = primary_system_index(priority_list, content.external_source)
          new_index = primary_system_index(priority_list, new_external_system)

          return false if current_index.nil? # current system not in priority list
          return false if new_index.nil? # new system not in priority list

          new_index < current_index
        end

        def update_primary_key?(content, new_external_key)
          return false if new_external_key.blank?
          return false unless new_external_key.respond_to?(:priority)

          current_index = content.try(:dc_ext_key_priority)
          new_index = new_external_key.priority

          return false if new_index.nil?
          return !DataCycleCore::Thing.exists?(external_source_id: content.external_source_id, external_key: new_external_key) if current_index.nil? && new_index.present?

          if new_index < current_index
            !DataCycleCore::Thing.exists?(external_source_id: content.external_source_id, external_key: new_external_key)
          else
            false
          end
        end
      end
    end
  end
end
