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
          OVERLAY_PROP_EXCEPTIONS = ['overlay', 'default_value', 'compute', 'virtual', 'content_score', 'exif', 'validations', 'api', 'label'].freeze
          OVERLAY_REGEX = Regexp.new([BASE_OVERLAY_POSTFIX, VIRTUAL_OVERLAY_POSTFIX, ADD_OVERLAY_POSTFIX].join('|'), 'i')

          def overlay_version_prop(key, prop, version)
            version_prop = prop.deep_dup.except(*OVERLAY_PROP_EXCEPTIONS)
            version_prop['features'] ||= {}
            version_prop['features']['overlay'] ||= {}
            version_prop['features']['overlay']['allowed'] = true
            version_prop['features']['overlay']['overlay_for'] = key
            version_prop['local'] = true
            version_prop['position'] = { 'after' => key }
            version_prop['visible'] = ['show', 'edit']

            version_prop['ui']&.each_value do |v|
              v.delete('content_area') if v.is_a?(::Hash) && v['content_area'] == 'none'
            end

            version_prop['ui'] ||= {}
            version_prop['ui']['edit'] ||= {}
            version_prop['ui']['edit']['data_attributes'] ||= {}
            version_prop['ui']['edit']['data_attributes']['overlay_type'] = version
            version_prop['ui']['edit']['options'] ||= {}
            version_prop['ui']['edit']['options']['class'] = [version_prop['ui']['edit']['options']['class'], 'dc-overlay', "dc-overlay-#{version}"].compact.join(' ')

            version_prop.deep_reject { |_k, v| v.blank? }
          end

          def overlay_prop(key, prop, versions)
            overlay_prop = overlay_version_prop(key, prop, 'overlay')
            overlay_prop['api'] = prop['api'] || {}
            overlay_prop['api']['name'] = key.camelize(:lower)
            overlay_prop['visible'] = ['api']
            overlay_prop['features'].delete('overlay')
            overlay_prop['virtual'] = {
              'module' => 'Common',
              'method' => 'overlay',
              'parameters' => [key, *versions]
            }

            overlay_prop.deep_reject { |_k, v| v.blank? }
          end

          def add_overlay_properties!(properties)
            overlay_props = properties.filter { |_k, prop| prop&.[](:overlay) }

            return properties if overlay_props.blank?

            overlay_props.each do |key, prop|
              versions = Overlay.allowed_postfixes_for_type(prop['type'])
              versions.map! { |v| key + v }
              versions.each do |version|
                properties[version] = overlay_version_prop(key, prop, version.delete_prefix("#{key}_"))
              end

              properties[key + VIRTUAL_OVERLAY_POSTFIX] = overlay_prop(key, prop, versions)
            end

            properties
          end

          def self.allowed_postfixes_for_type(type)
            Array.wrap(OVERLAY_POSTFIXES[type].dup || [BASE_OVERLAY_POSTFIX])
          end

          def self.overlay_attribute?(key)
            OVERLAY_REGEX.match?(key)
          end

          def self.overlay_attribute_type(key)
            key&.scan(OVERLAY_REGEX)&.first&.delete_prefix('_')
          end

          def self.key_without_overlay_type(key)
            key&.sub(OVERLAY_REGEX, '')
          end
        end
      end
    end
  end
end
