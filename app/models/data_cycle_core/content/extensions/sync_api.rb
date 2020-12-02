# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module SyncApi
        def to_sync_data
          available_locales.map { |lang|
            { lang => I18n.with_locale(lang) { to_sync_h } }
          }.inject(&:merge)
          &.merge({ included: attribute_to_sync_h('included') })
        end

        def to_sync_h
          (property_names - virtual_property_names)
            .map { |property_name| { property_name.to_s => attribute_to_sync_h(property_name) } }
            .inject(&:merge)
            .merge(sync_metadata)
            .compact
            .deep_stringify_keys
        end

        def attribute_to_sync_h(property_name)
          if plain_property_names.include?(property_name)
            send(property_name)
          elsif classification_property_names.include?(property_name)
            # send(property_name).try(:pluck, :id)
          elsif linked_property_names.include?(property_name)
            linked_array = get_property_value(property_name, property_definitions[property_name]).pluck(:id)
            linked_array.presence || []
          elsif included_property_names.include?(property_name)
            embedded_hash = send(property_name).to_h
            embedded_hash.presence
          elsif embedded_property_names.include?(property_name)
            return nil if property_name == overlay_name
            embedded_array = send(property_name)
            embedded_array = embedded_array.map(&:to_sync_data) if embedded_array.present?
            embedded_array.blank? ? [] : embedded_array.compact
          elsif asset_property_names.include?(property_name)
            send(property_name)
          elsif computed_property_names.include?(property_name)
            send(property_name)
          elsif schedule_property_names.include?(property_name)
            schedule_array = send(property_name)
            schedule_array = schedule_array.map(&:to_h).presence
            schedule_array.blank? ? [] : schedule_array.compact
          elsif property_name == 'included'
            linked_property_names.map { |linked|
              linked_array = get_property_value(linked, property_definitions[linked], nil, true)
              linked_array = linked_array.map(&:to_sync_data).map { |i| i.merge({ attribute_name: linked }) } if linked_array.present?
              linked_array.presence || []
            }.inject(:+)&.compact
          else
            raise StandardError, "Can not determine how to serialize #{property_name} for sync_api."
          end
        end

        def sync_metadata
          {
            template_name: template_name,
            updated_at: updated_at,
            created_at: created_at,
            external_key: external_key,
            external_source_id: external_source_id,
            external_source: external_source.identifier,
            external_system_syncs: external_system_syncs.map(&:to_hash)
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
