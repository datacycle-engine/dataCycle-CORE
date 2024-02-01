# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateTransformer
        VISIBILITIES = {
          'api' => { 'api' => { 'disabled' => true } },
          'xml' => { 'xml' => { 'disabled' => true } },
          'show' => { 'ui' => { 'show' => { 'disabled' => true } } },
          'edit' => { 'ui' => { 'edit' => { 'disabled' => true } } }
        }.freeze

        attr_reader :template, :mixin_paths

        def initialize(template:, content_set: nil, mixins: nil, templates: nil)
          @template = template.with_indifferent_access
          @content_set = content_set
          @mixins = mixins
          @templates = templates
          @mixin_paths = []
        end

        def main_config_property(key)
          DataCycleCore.main_config.dig(:templates, @content_set, @template[:name], key) || {}
        end

        def transform
          merge_base_templates! if @template.key?(:extends)
          @template[:boost] ||= 1.0
          (@template[:features] ||= {}).deep_merge!(main_config_property(:features))
          @template[:properties] = transform_properties
          @template[:api] = main_config_property(:api).presence || @template[:api].presence || {}

          @mixin_paths.uniq! { |v| v.split('=>')&.first }

          @template
        end

        def transform_properties
          new_properties = replace_mixin_properties(@template[:properties])

          new_properties.deep_merge!(main_config_property(:properties))
          add_sorting_recursive!(new_properties)
          add_missing_parameters!(new_properties)
          transform_visibilities!(new_properties)

          new_properties
        end

        def merge_base_templates!
          flat_templates = @templates.values.flatten

          Array.wrap(@template[:extends]).each do |extends_name|
            base_template = flat_templates.find { |v| v[:name] == extends_name }

            raise "BaseTemplates missing for #{extends_name}" if base_template.blank?

            @template = base_template[:data].deep_dup.deep_merge(@template)
            @mixin_paths.concat(base_template[:mixins])
          end

          @template.delete(:extends)
        end

        def add_missing_parameters!(properties)
          return properties if properties.blank?

          properties.filter { |_k, prop| prop&.dig(:compute, :parameters_path).present? }.each_value do |value|
            value[:compute][:parameters] = []

            Array.wrap(value[:compute].delete(:parameters_path)).each do |path|
              value[:compute][:parameters].concat(Array.wrap(@template.dig(*path.split('.'))))
            end
          end

          properties
        end

        def sort_properties!(properties)
          sortable_props = properties.filter { |_k, prop| prop&.key?(:position) }

          return properties if sortable_props.blank?

          ordered_keys = properties.keys

          sortable_props.each do |k, prop|
            position = prop.delete(:position)
            ordered_keys.delete(k)

            if position.key?(:after)
              new_index = ordered_keys.index(position[:after]) + 1
            else
              new_index = ordered_keys.index(position[:before])
            end

            ordered_keys.insert(new_index, k)
          end

          properties.slice!(*ordered_keys)
          properties
        end

        def add_sorting_recursive!(properties)
          return properties if properties.blank?

          sort_properties!(properties)

          properties.deep_reject! { |_, v| v.nil? }

          properties.each_value.with_index(1) do |value, index|
            value[:sorting] = index

            add_sorting_recursive!(value[:properties]) if value[:type] == 'object' && value.key?(:properties)
          end

          properties
        end

        def transform_visibilities!(properties)
          return properties if properties.blank?

          properties.transform_values! do |value|
            next value unless value&.key?(:visible)

            visibility = value.delete(:visible)

            next value if visibility == true

            visibilities = visibility == false ? VISIBILITIES : VISIBILITIES.except(*Array.wrap(visibility))

            visibilities.values.reduce(&:deep_merge).deep_merge(value).with_indifferent_access
          end

          properties
        end

        def replace_mixin_properties(props)
          properties = ActiveSupport::HashWithIndifferentAccess.new

          props&.each do |key, value|
            next if value.nil?
            next properties[key] = value unless value[:type] == 'mixin'

            properties.merge!(replace_mixin_property(value[:name].to_sym))
          end

          properties
        end

        def replace_mixin_property(property_name)
          template_name = @template[:name].underscore_blanks
          mixin = @mixins&.dig(property_name)&.find do |m|
            (m[:set] == @content_set || m[:set].nil?) &&
              (m[:template_name] == template_name || m[:template_name].nil?)
          end

          raise "mixin for #{property_name} not found!" if mixin.nil?
          return {} if mixin[:properties].blank?

          @mixin_paths.unshift("#{@content_set}.#{@template[:name]}.#{property_name} => #{mixin[:path]}")

          replace_mixin_properties(mixin[:properties])
        end
      end
    end
  end
end
