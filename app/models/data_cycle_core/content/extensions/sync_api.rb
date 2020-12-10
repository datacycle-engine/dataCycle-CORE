# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module SyncApi
        def to_sync_data(depth = 0)
          depth += 1
          return if depth > DataCycleCore.main_config.dig(:sync_api, :max_depth)
          (available_locales.presence || [I18n.locale]).map { |lang|
            { lang => I18n.with_locale(lang) { to_sync_h } }
          }.inject(&:merge)
          &.merge({ included: attribute_to_sync_h('included', depth) })
          &.deep_stringify_keys
        end

        def to_sync_h(depth = 0)
          (property_names - virtual_property_names)
            .map { |property_name| { property_name.to_s => attribute_to_sync_h(property_name, depth) } }
            .inject(&:merge)
            .merge(sync_metadata)
            .compact
            .deep_stringify_keys
        end

        def attribute_to_sync_h(property_name, depth = 0)
          present_overlay = overlay_property_names.include?(property_name)
          property_name_with_overlay = property_name
          property_name_with_overlay = "#{property_name}_#{overlay_name}" if overlay_property_names.include?(property_name) && property_name != 'id'
          if plain_property_names.include?(property_name)
            send(property_name_with_overlay)
          elsif classification_property_names.include?(property_name)
            # send(property_name).try(:pluck, :id)
          elsif linked_property_names.include?(property_name)
            linked_array = get_property_value(property_name, property_definitions[property_name], nil, present_overlay).pluck(:id)
            linked_array.presence || []
          elsif included_property_names.include?(property_name)
            embedded_hash = send(property_name_with_overlay).to_h
            embedded_hash.presence
          elsif embedded_property_names.include?(property_name)
            return nil if property_name == overlay_name
            embedded_array = send(property_name_with_overlay)
            embedded_array = embedded_array.map(&:to_sync_data) if embedded_array.present?
            embedded_array.blank? ? [] : embedded_array.compact
          elsif asset_property_names.include?(property_name)
            send(property_name_with_overlay)
          elsif computed_property_names.include?(property_name)
            send(property_name_with_overlay)
          elsif schedule_property_names.include?(property_name)
            schedule_array = send(property_name_with_overlay)
            schedule_array = schedule_array
              .map(&:to_h)
              .map { |i|
                i.delete('thing_id')
                i
              }.presence
            schedule_array.blank? ? [] : schedule_array.compact
          elsif property_name == 'included'
            linked_property_names.map { |linked|
              linked_array = get_property_value(linked, property_definitions[linked], nil, present_overlay)
              linked_array = linked_array
                &.map { |i| i.to_sync_data(depth) }
                &.map { |i| i.merge({ attribute_name: linked }) }
              linked_array.presence || []
            }.inject(:+)&.compact || []
          else
            raise StandardError, "Can not determine how to serialize #{property_name} for sync_api."
          end
        end

        def sync_metadata
          {
            template_name: template_name,
            updated_at: updated_at,
            created_at: created_at,
            last_sync_at: updated_at,
            last_successful_sync_at: updated_at,
            status: 'success',
            external_key: external_key,
            external_source_id: external_source_id,
            external_source: external_source&.identifier,
            external_system_syncs: external_system_syncs.map { |i|
              {
                'external_key' => i.external_key,
                'status' => i.status,
                'last_sync_at' => i.last_sync_at,
                'sync_type' => 'import',                
                'last_successful_sync_at' => i.last_successful_sync_at,
                'name' => DataCycleCore::ExternalSystem.find(i.external_system_id)&.identifier
              }
            }.compact
          }
        end

        def to_sync_api_deleted
          {
            'id' => id,
            'deleted_at' => deleted_at
          }
        end
      end
    end
  end
end
