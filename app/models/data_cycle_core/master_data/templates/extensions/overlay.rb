# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module Overlay
          BASE_OVERLAY_POSTFIX = '_override'
          VIRTUAL_OVERLAY_POSTFIX = '_overlay'
          ADD_OVERLAY_POSTFIX = '_add'
          OVERLAY_POSTFIXES = {
            'embedded' => [BASE_OVERLAY_POSTFIX, ADD_OVERLAY_POSTFIX].freeze,
            'linked' => [BASE_OVERLAY_POSTFIX, ADD_OVERLAY_POSTFIX].freeze,
            'classification' => [ADD_OVERLAY_POSTFIX].freeze,
            'opening_time' => [BASE_OVERLAY_POSTFIX, ADD_OVERLAY_POSTFIX].freeze,
            'schedule' => [BASE_OVERLAY_POSTFIX, ADD_OVERLAY_POSTFIX].freeze
          }.freeze
          OVERLAY_PROP_EXCEPTIONS = [
            'overlay',
            'default_value',
            'compute',
            'virtual',
            'content_score',
            'exif',
            'validations',
            'api',
            'label',
            'position'
          ].freeze
          ALLOWED_PROP_OVERRIDES = ['default_value', 'ui'].freeze

          def overlay_version_prop(key, prop, version, allowed_visibilities = ['show', 'edit'])
            version_prop = prop.deep_dup.except(*OVERLAY_PROP_EXCEPTIONS)
            override_props = version_prop.dig('features', 'overlay', version)&.slice(*ALLOWED_PROP_OVERRIDES) || {}
            version_prop.deep_merge!(override_props)

            version_prop['features'] = {
              'overlay' => {
                'overlay_for' => key,
                'overlay_type' => version
              }
            }
            version_prop['local'] = true
            version_prop['visible'] = Visible.merge_visibility(version_prop['visible'], allowed_visibilities)
            version_prop['label'] = { key:, key_suffix: "overlay_#{version}" }

            if version_prop['storage_location'] == 'column'
              version_prop['storage_location'] = key == 'slug' ? 'translated_value' : 'value'
            end

            version_prop['ui']&.each_value do |v|
              v.delete('content_area') if v.is_a?(::Hash) && v['content_area'] == 'none'
            end

            remove_readonly_recursively!(version_prop)
            version_prop['ui'] ||= {}
            version_prop['ui']['edit'] ||= {}
            version_prop['ui']['edit']['data_attributes'] ||= {}
            version_prop['ui']['edit']['data_attributes']['overlay_type'] = version

            version_prop.deep_reject { |_k, v| DataHashService.blank?(v) }
          end

          def remove_readonly_recursively!(prop)
            return unless prop.is_a?(Hash)

            prop['ui']['edit'].delete('readonly') if prop.dig('ui', 'edit')&.key?('readonly')

            return unless prop['type'] == 'object' && prop['properties'].is_a?(Hash)

            prop['properties'].each_value do |sub_prop|
              remove_readonly_recursively!(sub_prop)
            end
          end

          def overlay_prop(key, prop, versions)
            overlay_prop = overlay_version_prop(key, prop, 'overlay', ['api'])
            overlay_prop['api'] = prop['api']&.deep_dup || {}
            overlay_prop['api']['name'] = key.camelize(:lower) if overlay_prop.dig('api', 'name').blank?
            overlay_prop['visible'] = ['api'] unless overlay_prop.key?('visible') || overlay_prop.dig('api', 'disabled') || overlay_prop.dig('api', 'v4', 'disabled')
            overlay_prop['virtual'] = {
              'module' => 'Common',
              'method' => 'overlay',
              'parameters' => [key, *versions]
            }

            overlay_prop.deep_reject { |_k, v| DataHashService.blank?(v) }
          end

          def add_overlay_properties!(properties)
            overlay_props = properties.filter { |_k, prop| prop&.[](:overlay) }

            return properties if overlay_props.blank?

            all_props = properties.to_a

            overlay_props.each do |key, prop|
              new_index = all_props.pluck(0).index(key) + 1
              transform_prop_with_overlay!(prop)
              versions = Overlay.allowed_postfixes_for_type(prop['type'])
              versions.map! { |v| key + v }
              new_versions = versions.map do |version|
                [version, overlay_version_prop(key, prop, version.delete_prefix("#{key}_"))]
              end

              new_versions.push([key + VIRTUAL_OVERLAY_POSTFIX, overlay_prop(key, prop, versions)])
              all_props.insert(new_index, *new_versions)
            end

            properties.clear.merge!(all_props.to_h)
          end

          def transform_prop_with_overlay!(prop)
            prop.delete('overlay')
            prop['features'] ||= {}
            prop['features'].deep_merge!({ 'overlay' => { allowed: true } })
          end

          def self.allowed_postfixes_for_type(type)
            Array.wrap(OVERLAY_POSTFIXES[type].dup || [BASE_OVERLAY_POSTFIX])
          end

          def self.disable_original_property!(prop)
            prop['api'] ||= {}
            prop['api']['disabled'] = true
            prop['api']['v4']['disabled'] = true if prop.dig('api', 'v4')&.key?('disabled')
          end

          def self.disable_original_properties!(properties)
            properties.each_value do |prop|
              disable_original_property!(prop) if prop&.dig('features', 'overlay', 'allowed')
            end
          end
        end
      end
    end
  end
end
