# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateTransformer
        include Extensions::Overlay
        include Extensions::Position
        include Extensions::Visible

        attr_reader :template, :mixin_paths

        def initialize(template:, content_set: nil, mixins: nil, templates: nil)
          @template = template.with_indifferent_access
          @content_set = content_set
          @mixins = mixins
          @templates = templates
          @mixin_paths = []
          @errors = []
          @error_path = "#{@content_set}.#{@template[:name]}"
        end

        def self.merge_base_templates(template:, templates:)
          return template unless template.key?(:extends)

          Array.wrap(template[:extends]).each do |extends_name|
            base_template = templates.find { |v| v[:name] == extends_name }

            raise TemplateError.new('extends'), "BaseTemplate missing for #{extends_name}" if base_template.blank?

            template = base_template[:data].deep_dup.deep_merge(template.except(:extends))
          end

          template
        end

        def main_config_property(key)
          DataCycleCore.main_config.dig(:templates, @content_set, @template[:name], key) || {}
        end

        def transform
          return @template, @errors if @transform_properties == false

          @template[:boost] ||= 1.0
          (@template[:features] ||= {}).deep_merge!(main_config_property(:features))
          @template[:properties] = transform_properties
          @template[:api] = main_config_property(:api).presence || @template[:api].presence || {}

          @mixin_paths.uniq! { |v| v.split('=>')&.first }

          return @template, @errors
        end

        def transform_properties
          new_properties = replace_mixin_properties(@template[:properties])

          new_properties.deep_merge!(main_config_property(:properties))
          add_overlay_properties!(new_properties)
          add_sorting_recursive!(new_properties)
          add_missing_parameters!(new_properties)
          transform_visibilities!(new_properties)

          new_properties
        end

        def add_missing_parameters!(properties)
          return properties if properties.blank?

          resolve_computed_params_path!(properties)
          hide_inverse_linked_in_edit_mode!(properties)
          filter_conditional_properties!(properties)

          properties
        end

        def resolve_computed_params_path!(properties)
          properties.filter { |_k, prop| prop&.dig(:compute, :parameters_path).present? }.each_value do |value|
            value[:compute][:parameters] = []

            Array.wrap(value[:compute].delete(:parameters_path)).each do |path|
              value[:compute][:parameters].concat(Array.wrap(@template.dig(*path.split('.'))))
            end
          end
        end

        def hide_inverse_linked_in_edit_mode!(properties)
          properties.filter { |_k, prop| prop&.dig(:link_direction) == 'inverse' }.each_value do |value|
            value[:visible] = VISIBILITIES.keys.except('edit') unless value.key?(:visible)
          end
        end

        def filter_conditional_properties!(properties)
          properties.reject! do |k, prop|
            prop.key?(:condition) && !allowed_property?(key: k, property: prop, properties:)
          end
        end

        def replace_mixin_properties(props, additional_attributes = {}, additional_path = [])
          properties = ActiveSupport::HashWithIndifferentAccess.new

          props&.each do |key, value|
            if value.nil?
              properties.delete(key)
            elsif value[:type] == 'mixin'
              # deep reverse merge
              m_proc = ->(_, v1, v2) { v1.is_a?(::Hash) && v2.is_a?(::Hash) ? v1.merge(v2, &m_proc) : v1 }
              properties.merge!(replace_mixin_property(key, value[:name].to_sym, value.except(:name, :type), additional_path), &m_proc)
            else
              properties.deep_merge!({ key => value&.merge(additional_attributes) })
            end
          end

          properties.deep_reject! { |_, v| v.nil? }
          properties
        end

        def replace_mixin_property(key, property_name, additional_attributes, additional_path = [])
          template_name = @template[:name].underscore_blanks
          mixin = @mixins&.dig(property_name)&.find do |m|
            (m[:set] == @content_set || m[:set].nil?) &&
              (m[:template_name] == template_name || m[:template_name].nil?)
          end

          if mixin.nil?
            @errors.push("#{@error_path}.properties.#{key} => mixin for #{property_name} not found!")
            return {}
          end

          return {} if mixin[:properties].blank?

          @mixin_paths.unshift("#{@content_set}.#{@template[:name]}.#{key} => #{mixin[:path]}")

          replace_mixin_properties(mixin[:properties], additional_attributes, additional_path + [key])
        end

        private

        def keys_from_parameters(property)
          return [] if property.blank?

          property.dig(:compute, :parameters).presence ||
            property.dig(:default_value, :parameters).presence ||
            property.dig(:virtual, :parameters).presence
        end

        def allowed_property?(key:, property:, properties:)
          property[:condition].blank? || property.delete(:condition).all? do |cond_key, value|
            if respond_to?(:"condition_#{cond_key}", true)
              send(:"condition_#{cond_key}", key:, property:, value:, properties:)
            else
              @errors.push("#{@error_path}.properties.#{key}.condition.#{cond_key} => method not found!")
            end
          end
        end

        def condition_parameters_exist?(property:, properties:, **)
          keys = keys_from_parameters(property)

          return true if keys.blank?

          keys.any? { |path| properties.key?(path.split('.').first) }
        end

        def condition_parameters_exist_with_type?(property:, value:, properties:, **)
          keys = keys_from_parameters(property)

          return true if keys.blank?

          keys.any? { |path| properties.dig(path.split('.').first, 'type').in?(Array.wrap(value)) }
        end

        def condition_template_key?(value:, **)
          path = value.split('.')
          last = path.pop
          base = path.present? ? template.dig(*path) : template

          return false if base.nil?

          base.key?(last)
        end

        def condition_not_content_type?(**)
          !condition_content_type?(**)
        end

        def condition_content_type?(value:, **)
          content_types = Array.wrap(value)
          content_types.include?(template['content_type'])
        end

        def condition_feature_allowed?(value:, **)
          DataCycleCore.features.dig(value, 'enabled') &&
            (
              DataCycleCore.features.dig(value, 'allowed') ||
              template.dig('features', value, 'allowed')
            )
        end
      end
    end
  end
end
