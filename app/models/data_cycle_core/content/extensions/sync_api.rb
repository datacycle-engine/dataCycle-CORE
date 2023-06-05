# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module SyncApi
        def to_sync_data(depth: 0, locales: nil, translated: false, max_depth: DataCycleCore.main_config.dig(:sync_api, :max_depth))
          depth += 1
          return if depth > max_depth
          languages = available_locales.presence || [I18n.locale]
          languages = locales if locales.present? && translated
          languages.map { |lang|
            { lang => I18n.with_locale(lang) { to_sync_h(locales: locales, depth: depth, max_depth: max_depth) } }
          }.inject(&:merge)
          &.merge({ included: attribute_to_sync_h('included', depth: depth, max_depth: max_depth) })
          &.merge({ classifications: attribute_to_sync_h('classifications', depth: depth, max_depth: max_depth) })
          &.deep_stringify_keys
        end

        def to_sync_h(depth: 0, max_depth: DataCycleCore.main_config.dig(:sync_api, :max_depth), locales: nil)
          (property_names - timeseries_property_names)
            .map { |property_name| { property_name.to_s => attribute_to_sync_h(property_name, depth: depth, max_depth: max_depth, locales: locales) } }
            .inject(&:merge)
            .merge(sync_metadata)
            .tap { |sync_data| sync_data['universal_classifications'] += attribute_to_sync_h('mapped_classifications', depth: depth, max_depth: max_depth, locales: locales) }
            .deep_stringify_keys
        end

        def attribute_to_sync_h(property_name, max_depth:, depth: 0, locales: nil)
          present_overlay = overlay_property_names.include?(property_name)
          property_name_with_overlay = property_name
          property_name_with_overlay = "#{property_name}_#{overlay_name}" if overlay_property_names.include?(property_name) && property_name != 'id'
          if plain_property_names.include?(property_name)
            send(property_name_with_overlay)
          # elsif computed_property_names.include?(property_name)
          #   send(property_name_with_overlay)
          elsif classification_property_names.include?(property_name)
            send(property_name).try(:pluck, :id)
          elsif linked_property_names.include?(property_name)
            return [] if depth >= max_depth
            return [] if properties_for(property_name)['link_direction'] == 'inverse'
            linked_array = get_property_value(property_name, property_definitions[property_name], nil, present_overlay).pluck(:id)
            linked_array.presence || []
          elsif included_property_names.include?(property_name)
            embedded_hash = send(property_name_with_overlay).to_h
            embedded_hash.presence
          elsif embedded_property_names.include?(property_name)
            return nil if property_name == overlay_name
            embedded_array = send(property_name_with_overlay)
            translated = property_definitions[property_name]['translated']
            embedded_array = embedded_array&.map { |i| i.to_sync_data(translated: translated, locales: locales) }
            embedded_array.blank? ? [] : embedded_array.compact
          elsif asset_property_names.include?(property_name)
            # send(property_name_with_overlay) # do nothing --> only import url not asset itself
          elsif schedule_property_names.include?(property_name)
            schedule_array = send(property_name_with_overlay)
            schedule_array = schedule_array
              .map(&:to_h)
              .map { |i| i.tap { |j| j.delete(:thing_id) } }
              .presence
            schedule_array.blank? ? [] : schedule_array.compact
          elsif property_name == 'included'
            linked_property_names.map { |linked|
              next if properties_for(linked)['link_direction'] == 'inverse'
              present_overlay = overlay_property_names.include?(linked)
              property_name_with_overlay = linked
              property_name_with_overlay = "#{linked}_#{overlay_name}" if overlay_property_names.include?(linked)
              linked_array = get_property_value(linked, property_definitions[linked], nil, present_overlay)
              linked_array = linked_array
                &.map { |i| i.to_sync_data(depth: depth)&.merge({ attribute_name: linked }) }
              linked_array.compact.presence || []
            }.compact.inject(:+)&.compact || []
          elsif property_name == 'classifications'
            classification_property_names&.map { |classification_property_name|
              classification_property_name_overlay = classification_property_name
              classification_property_name_overlay = "#{classification_property_name}_#{overlay_name}" if overlay_property_names.include?(classification_property_name)
              send(classification_property_name_overlay)&.map { |classification|
                classification_data = classification
                  .to_hash
                  .merge({ 'ancestors' => classification.ancestors.map(&:to_hash) })
                  .merge({ 'attribute_name' => classification_property_name })

                classification_mappings = classification.mapped_to&.map { |alias_data|
                  primary_classification = alias_data.primary_classification
                  next if primary_classification.nil?
                  primary_classification
                    .to_hash
                    .merge({ 'ancestors' => primary_classification.ancestors&.map(&:to_hash) })
                    .merge({ 'attribute_name' => 'universal_classifications' })
                }&.compact
                Array.wrap(classification_data) + classification_mappings
              }.presence&.flatten
            }&.compact&.flatten
          elsif property_name == 'mapped_classifications'
            classification_property_names&.map { |classification_property_name|
              classification_property_name_overlay = classification_property_name
              classification_property_name_overlay = "#{classification_property_name}_#{overlay_name}" if overlay_property_names.include?(classification_property_name)
              send(classification_property_name_overlay)&.map { |classification|
                classification.mapped_to&.map do |alias_data|
                  alias_data.primary_classification&.id
                end
              }.presence&.flatten
            }&.compact&.flatten
          else
            raise StandardError, "Can not determine how to serialize #{property_name} for sync_api."
          end
        end

        def sync_metadata
          sm = {
            template_name: template_name,
            updated_at: updated_at,
            created_at: created_at,
            external_key: external_key,
            external_source_id: external_source_id,
            external_source: external_source&.identifier
          }
          unless embedded?
            sm = sm.merge({
              last_sync_at: updated_at,
              last_successful_sync_at: updated_at,
              status: 'success',
              external_system_syncs: external_system_syncs.map { |i|
                {
                  'external_key' => i.external_key || id,
                  'status' => i.status,
                  'last_sync_at' => i.last_sync_at,
                  'sync_type' => 'duplicate',
                  'last_successful_sync_at' => i.last_successful_sync_at,
                  'name' => DataCycleCore::ExternalSystem.find(i.external_system_id)&.identifier
                }
              }.compact
            })
          end
          sm
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
