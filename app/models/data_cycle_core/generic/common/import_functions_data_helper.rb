# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctionsDataHelper
        def process_step(utility_object:, raw_data:, transformation:, default:, config:)
          template = config&.dig(:template) || default.dig(:template)

          if config&.key?(:before)
            whitelist = config.dig(:before, :whitelist)
            raw_data = Transformations::BlacklistWhitelistFunctions.apply_whitelist(raw_data, whitelist) if whitelist.present?
            blacklist = config.dig(:before, :blacklist)
            raw_data = Transformations::BlacklistWhitelistFunctions.apply_blacklist(raw_data, blacklist) if blacklist.present?
          end

          data = merge_default_values(
            config,
            transformation.call(raw_data || {}),
            utility_object
          ).with_indifferent_access

          if config&.key?(:after)
            whitelist = config.dig(:after, :whitelist)
            data = Transformations::BlacklistWhitelistFunctions.apply_whitelist(data, whitelist) if whitelist.present?
            blacklist = config.dig(:after, :blacklist)
            data = Transformations::BlacklistWhitelistFunctions.apply_blacklist(data, blacklist) if blacklist.present?
          end

          create_or_update_content(
            utility_object: utility_object,
            template: load_template(template),
            data: data,
            local: false,
            config: config
          )
        end

        def create_or_update_content(utility_object:, template:, data:, local: false, config: {})
          return nil if data.except('external_key', 'locale').blank?

          if local
            content = DataCycleCore::Thing.new(
              local_import: true
            )
          else
            # try to find already present content:
            content = DataCycleCore::Thing.by_external_key(utility_object.external_source.id, data['external_key']).first
            if content.blank? && data['external_system_data'].present?
              data['external_system_data'].each do |external_system_entry|
                external_system = DataCycleCore::ExternalSystem.find_by(identifier: external_system_entry['identifier'] || external_system_entry['name'])
                next if external_system.blank?
                next if external_system_entry['external_key'].blank?
                content ||= DataCycleCore::Thing.by_external_key(external_system&.id, external_system_entry['external_key']).first
              end
            end

            # add external_system_syncs where necessary and return
            if content.present?
              present_external_systems = content.view_all_external_data
              all_imported_external_system_data = data['external_system_data'] || []
              all_imported_external_system_data += [{
                'external_key' => data['external_key'],
                'name' => utility_object.external_source.name,
                'identifier' => utility_object.external_source.identifier,
                'last_sync_at' => data.dig('updated_at'),
                'last_successful_sync_at' => data.dig('updated_at')
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

              return content if content&.external_source_id != utility_object.external_source.id || content&.external_key != data['external_key']
            end

            # no content found anywhere --> create new thing
            content ||= DataCycleCore::Thing.new(
              external_source_id: utility_object.external_source.id,
              external_key: data['external_key']
            )
          end

          created = false
          content.webhook_source = utility_object&.external_source&.name

          if content.new_record?
            content.metadata ||= {}
            content.schema = template.schema
            content.template_name = template.template_name
            content.created_by = data['created_by']
            created = true
            content.save!
          end

          global_data = content.to_h_partial((content.global_property_names + DataCycleCore::Feature::OverlayAttributeService.call(content)))
          global_data.reject! { |_, v| DataCycleCore::DataHashService.blank?(v) }
          global_data.merge!(data)
          global_data.except!('external_key') unless created

          if config&.dig(:asset_type).present?
            if utility_object.asset_download
              content.asset.try(:remove_file!)
              if data.dig('binary_file_blob').present? && data.dig('binary_file_name').present?
                full_file_path = Rails.root.join('tmp', data.dig('binary_file_name'))
                File.binwrite(full_file_path.to_s, [data.dig('binary_file_blob')].pack('H*'))
                asset = config
                  .dig(:asset_type)
                  .constantize
                  .new(name: data.dig('binary_file_name'))
                asset.file.attach(io: File.open(full_file_path), filename: data.dig('binary_file_name'))
                # full_file_path.delete
              elsif data.dig('binary_file').present? && data.dig('binary_file_name').present?
                tempfile = File.new(Rails.root.join('tmp', data.dig('binary_file_name')), 'w')
                tempfile.binmode
                tempfile.write(data.dig('binary_file'))
                tempfile.close
                asset = config.dig(:asset_type).constantize.new(file: Pathname.new(Rails.root.join('tmp', data.dig('binary_file_name'))).open)
                Rails.root.join('tmp', data.dig('binary_file_name')).delete
              else
                asset = config.dig(:asset_type).constantize.new(remote_file_url: data.dig('remote_file_url'))
              end
              asset.save
              global_data['asset'] = asset.id
            else
              global_data['asset'] = content&.asset&.id
            end
          end

          if DataCycleCore::Feature::Normalize.enabled?
            normalize_options = {
              id: data['external_key'],
              comment: utility_object.external_source.name
            }
            normalized_data, _diff = utility_object.normalizer.normalize(global_data, template.schema, normalize_options)
          else
            normalized_data = global_data
          end

          current_user = data['updated_by'].present? ? DataCycleCore::User.find_by(id: data['updated_by']) : nil
          invalidate_related_cache = utility_object.external_source.default_options&.fetch('invalidate_related_cache', true)
          partial_update_improved = utility_object.external_source.default_options&.fetch('partial_update_improved', DataCycleCore.partial_update_improved) && !created

          valid = content.set_data_hash(
            data_hash: normalized_data,
            prevent_history: !utility_object.history,
            update_search_all: true,
            current_user: current_user,
            partial_update_improved: partial_update_improved,
            new_content: created,
            invalidate_related_cache: invalidate_related_cache
          )

          if valid
            ActiveSupport::Notifications.instrument 'object_import_succeeded.datacycle', this: {
              external_system: utility_object.external_source,
              external_type: utility_object.source_type.collection_name,
              template_name: content.template_name
            }
          else
            ActiveSupport::Notifications.instrument 'object_import_failed.datacycle', this: {
              external_system: utility_object.external_source,
              external_type: utility_object.source_type.collection_name,
              template_name: content.template_name
            }

            utility_object.logging&.error('Validating import data', data['external_key'], data, content.errors.messages.collect { |k, v| "#{k} #{v&.join(', ')}" }.join(', '))

            content.destroy_content(save_history: false) if created
            return
          end

          data.dig('external_system_data')&.each do |es|
            next if Array(utility_object.external_source.default_options['current_instance_identifiers']).include?(es['identifier'] || es['name'])

            external_system = DataCycleCore::ExternalSystem.find_from_hash(es)
            external_system = DataCycleCore::ExternalSystem.create!(name: es['name'] || es['identifier'], identifier: es['identifier'] || es['name']) if external_system.blank? && !utility_object.external_source.default_options&.[]('reject_unknown_external_systems')

            next if external_system.nil?

            sync_data = content.add_external_system_data(external_system, { external_key: es['external_key'] }, es['status'] || 'success', es['sync_type'] || 'duplicate', es['external_key'], es['external_key'].present?)
            update_data = { last_sync_at: es['last_sync_at'], last_successful_sync_at: es['last_successful_sync_at'] }.compact
            sync_data.update(update_data) if update_data.present?
          end

          content
        end

        def load_default_values(data_hash)
          return nil if data_hash.blank?
          return_data = {}
          data_hash.each do |key, value|
            return_data[key] = default_classification(**value.symbolize_keys)
          end
          return_data.reject { |_, value| value.blank? }
        end

        def load_template(template_name)
          I18n.with_locale(:de) do
            DataCycleCore::Thing.find_by!(template: true, template_name: template_name)
          end
        rescue ActiveRecord::RecordNotFound
          raise "Missing template #{template_name}"
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
          new_hash = load_default_values(config.dig(:default_values)) if config&.dig(:default_values).present?
          new_hash.merge!(data_hash)

          transform_external_system_data!(config, new_hash, utility_object)

          new_hash
        end

        def transform_external_system_data!(config, data_hash, utility_object)
          data_hash.delete('external_system_data') && return unless utility_object.external_source.default_options.to_h.slice('import_external_system_data').merge(config&.slice(:import_external_system_data).to_h.stringify_keys)['import_external_system_data']

          return if data_hash['external_system_data'].blank?

          transformation_config = utility_object.external_source.default_options&.[]('external_system_identifier_transformation')

          return unless transformation_config&.key?('module') && transformation_config&.key?('method')

          data_hash['external_system_data'].each { |d| d['identifier'] = transformation_config['module'].safe_constantize.send(transformation_config['method'], d['identifier']) }
        end

        def fixnum_max
          (2**(0.size * 4 - 2) - 1)
        end

        def logging_delta
          @logging_delta ||= 100
        end
      end
    end
  end
end