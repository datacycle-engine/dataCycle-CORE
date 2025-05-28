# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctionsDataHelper
        def process_step(utility_object:, raw_data:, transformation:, default:, config:, options:)
          return if DataCycleCore::DataHashService.deep_blank?(raw_data)
          template = load_template(config&.dig(:template) || default[:template])

          raw_data = pre_process_data(raw_data:, config:, utility_object:)

          data = merge_default_values(
            config,
            transformation.call(raw_data || {}),
            utility_object
          ).with_indifferent_access

          return if DataCycleCore::DataHashService.deep_blank?(data) || data['external_key'].blank?
          data = post_process_data(data:, config:, utility_object:).slice(*template.properties, 'external_system_data')
          transformation_hash = Digest::SHA256.hexdigest(data.to_json)
          external_key = data['external_key']
          external_source_id = utility_object.external_source.id
          external_hash = DataCycleCore::ExternalHash.find_or_initialize_by(external_key:, external_source_id:, locale: I18n.locale)

          if external_hash.hash_value == transformation_hash && utility_object.mode.to_s != 'reset'
            content = DataCycleCore::Thing.by_external_key(utility_object.external_source.id, data['external_key']).first
          else
            content = create_or_update_content(
              utility_object:,
              template:,
              data:,
              local: false,
              config:,
              options:
            )
            external_hash.hash_value = transformation_hash if content.present?
          end
          external_hash.seen_at = Time.zone.now
          external_hash.save if content&.persisted? && content.external_key == external_key && content.external_source_id == external_source_id
          content
        rescue StandardError => e
          ActiveSupport::Notifications.instrument 'object_import_failed.datacycle', {
            exception: e,
            namespace: 'importer',
            external_system: utility_object&.external_source,
            item_id: data&.dig('external_key') || raw_data&.dig('id'),
            template_name: template&.template_name
          }
          raise if Rails.env.local?
          nil
        end

        # 2173067 for template missmatch
        # 59471758 as poi
        def create_or_update_content(utility_object:, template:, data:, options:, local: false, **)
          return nil if data.except('external_key', 'locale').blank?
          delete_property_hash = {}
          if local
            content = DataCycleCore::Thing.new(
              local_import: true,
              template_name: template.template_name
            )
          else
            # try to find already present content:
            content = DataCycleCore::Thing.first_by_id_or_external_data(
              id: data['id'],
              external_key: data['external_key'],
              external_system: utility_object.external_source,
              external_system_syncs: data['external_system_data']
            )

            # add external_system_syncs where necessary and return
            if content.present?
              present_external_systems = content.view_all_external_data
              all_imported_external_system_data = data['external_system_data'] || []
              all_imported_external_system_data += [{
                'external_key' => data['external_key'],
                'name' => utility_object.external_source.name,
                'identifier' => utility_object.external_source.identifier,
                'last_sync_at' => data['updated_at'],
                'last_successful_sync_at' => data['updated_at']
              }]
              all_imported_external_system_data.each do |es|
                next if Array(utility_object.external_source.default_options&.dig('current_instance_identifiers')).include?(es['identifier'] || es['name'])

                next if present_external_systems.detect { |i| i['external_identifier'] == (es['identifier'] || es['name']) && i['external_key'] == es['external_key'] }.present?
                external_system = DataCycleCore::ExternalSystem.find_from_hash(es)
                external_system = DataCycleCore::ExternalSystem.create!(name: es['name'] || es['identifier'], identifier: es['identifier'] || es['name']) if external_system.blank? && !utility_object.external_source.default_options&.[]('reject_unknown_external_systems')

                next if external_system.nil?

                sync_data = content.add_external_system_data(external_system, { external_key: es['external_key'] }, es['status'] || 'success', es['sync_type'] || 'duplicate', es['external_key'], false)
                update_data = { last_sync_at: es['last_sync_at'], last_successful_sync_at: es['last_successful_sync_at'] }.compact
                sync_data.update(update_data) if update_data.present?
              end

              if content&.external_source_id != utility_object.external_source.id
                primary_source_module = options.dig(:import, :primary_system_decision_module)
                primary_source_methode = options.dig(:import, :primary_system_decision_method)
                return content unless primary_source_module && primary_source_methode
                
                primary_system_change_module = primary_source_module.safe_constantize
                return content unless primary_system_change_module.respond_to?(primary_source_methode)
                return content unless primary_system_change_module&.send(primary_source_methode, content, utility_object.external_source.id, options)
                delete_property_hash = change_primary_system_nonpersistent(content, data, utility_object.external_source)

              elsif content&.external_key != data['external_key']
                return content
              end

              raise DataCycleCore::Error::Import::TemplateMismatchError.new(template_name: content.template_name, expected_template_name: template.template_name, external_source: utility_object&.external_source, external_key: content.external_key) if content.template_name != template.template_name
            end

            # no content found anywhere --> create new thing
            content ||= DataCycleCore::Thing.new(
              external_source_id: utility_object.external_source.id,
              external_key: data['external_key'],
              template_name: template.template_name
            )
          end

          created = false
          content.webhook_source = utility_object&.external_source&.name
          if content.new_record?
            content.metadata ||= {}
            content.created_by = data['created_by']
            created = true
            content.save!
          end

          global_data = data.except(*content.local_property_names, 'overlay')
          global_data.except!('external_key') unless created

          current_user = data['updated_by'].present? ? DataCycleCore::User.find_by(id: data['updated_by']) : nil
          invalidate_related_cache = utility_object.external_source.default_options&.fetch('invalidate_related_cache', true)

          global_data = delete_property_hash.merge(global_data) if delete_property_hash.present?
          valid = content.set_data_hash(
            data_hash: global_data,
            prevent_history: !utility_object.history,
            update_search_all: true,
            current_user:,
            new_content: created,
            invalidate_related_cache:
          )

          if valid
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
            step_label = utility_object.step_label({ locales: [I18n.locale] })

            utility_object.logger.validation_error(step_label, global_data, errors)

            content.destroy_content(save_history: false) if created
            return
          end

          data['external_system_data']&.each do |es|
            next if Array(utility_object.external_source.default_options['current_instance_identifiers']).include?(es['identifier'] || es['name'])

            external_system = DataCycleCore::ExternalSystem.find_from_hash(es)
            external_system = DataCycleCore::ExternalSystem.create!(name: es['name'] || es['identifier'], identifier: es['identifier'] || es['name']) if external_system.blank? && !utility_object.external_source.default_options&.[]('reject_unknown_external_systems')

            next if external_system.nil?

            sync_data = content.add_external_system_data(external_system, { external_key: es['external_key'] }, es['status'] || 'success', es['sync_type'] || 'duplicate', es['external_key'], es['external_key'].present?)
            update_data = { last_sync_at: es['last_sync_at'], last_successful_sync_at: es['last_successful_sync_at'] }.compact
            sync_data.update(update_data) if update_data.present?
          end

          content
        rescue DataCycleCore::Error::Import::TemplateMismatchError => e
          ActiveSupport::Notifications.instrument 'object_import_failed_template.datacycle', {
            exception: e,
            namespace: 'importer',
            external_system: utility_object&.external_source
          }
          nil
        rescue StandardError => e
          ActiveSupport::Notifications.instrument 'object_import_failed.datacycle', {
            exception: e,
            namespace: 'importer',
            external_system: utility_object&.external_source,
            item_id: data['external_key'],
            template_name: template.template_name
          }
          raise if Rails.env.local?
          nil
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
            DataCycleCore::Thing.new(template_name:)
          end
        end

        def default_classification(value:, tree_label:)
          [
            DataCycleCore::Classification
              .joins(classification_groups: [classification_alias: [classification_tree: [:classification_tree_label]]])
              .where(classification_tree_labels: { name: tree_label }, classifications: { name: value })&.first&.id
          ].compact_blank
        end

        def merge_default_values(config, data_hash, utility_object)
          new_hash = {}
          new_hash = load_default_values(config[:default_values]) if config&.dig(:default_values).present?
          new_hash.merge!(data_hash)

          transform_external_system_data!(config, new_hash, utility_object)

          new_hash
        end

        def transform_external_system_data!(config, data_hash, utility_object)
          merged_config = utility_object
            .external_source
            .default_options
            .to_h
            .slice('import_external_system_data')
            .merge(config&.slice(:import_external_system_data).to_h.stringify_keys)
          data_hash.delete('external_system_data') && return if merged_config['import_external_system_data'].blank?

          return if data_hash['external_system_data'].blank?

          options = utility_object.external_source.default_options || {}

          if (mapping = options['external_system_identifier_mapping']).present?
            data_hash['external_system_data'].each do |d|
              d['identifier'] = mapping[d['identifier']] || d['identifier']
            end
          end

          transformation_config = options['external_system_identifier_transformation']

          return unless transformation_config&.key?('module') && transformation_config.key?('method')

          data_hash['external_system_data'].each do |d|
            t_module = transformation_config['module'].safe_constantize
            t_method = transformation_config['method']
            d['identifier'] = t_module.send(t_method, d['identifier'])
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
            class_name = DataCycleCore::ModuleService.load_module(processor[:module])

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
            class_name = DataCycleCore::ModuleService.load_module(processor[:module])

            Array.wrap(processor[:method]).each do |method_name|
              next unless class_name.respond_to?(method_name)

              data = class_name.send(method_name, data, utility_object)
            end
          end

          data
        end

        # delete future primary system from external_system_syncs
        # missing syncs are added after content update
        # maybe we should still add the old external system, to syncs so everything works as expected
        def change_primary_system_nonpersistent(content, data, new_external_source)
          content.external_system_syncs.load
          delete_sync = content.external_system_syncs.detect do |sync|
            sync.external_system_id == new_external_source.id && sync.external_key == data['external_key']
          end

          return {} if delete_sync.nil?
          delete_sync.mark_for_destruction

          content.external_key = data['external_key']
          content.external_source_id = new_external_source.id

          # return hash to clear old attributes
          content.allowed_importer_property_names.index_with { |_key| nil }
        end

        def fixnum_max
          ((2**((0.size * 4) - 2)) - 1)
        end

        def logging_delta
          @logging_delta ||= 100
        end

        def self.should_update_primary_system?(content, current_system_id, options)
          primary_system_priority_list = options.dig(:import, :primary_system_priority_order)
          quoted_names = primary_system_priority_list.map { |n| ActiveRecord::Base.connection.quote(n) }
          order_clause = quoted_names&.each_with_index&.map { |name, i| "WHEN #{name} THEN #{i}" }&.join(' ')

          primary_system_priority_ids = DataCycleCore::ExternalSystem.where(name: primary_system_priority_list).order(Arel.sql("CASE name #{order_clause} END")).pluck('id')
          return false if primary_system_priority_ids.blank?

          # If the current system is not found in the priority configuration -> skip
          # If any of the external_systems with higher priority is already the primary system -> skip
          current_system_index = primary_system_priority_ids.index(current_system_id)
          return false if current_system_index.nil?
          return false if primary_system_priority_ids[0...current_system_index].include?(content.external_source_id)
          true
        end
      end
    end
  end
end
