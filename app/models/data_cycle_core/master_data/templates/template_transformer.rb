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
          merge_base_templates! if @template.key?(:extends)
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

          properties.filter { |_k, prop| prop&.dig(:compute, :parameters_path).present? }.each_value do |value|
            value[:compute][:parameters] = []

            Array.wrap(value[:compute].delete(:parameters_path)).each do |path|
              value[:compute][:parameters].concat(Array.wrap(@template.dig(*path.split('.'))))
            end
          end

          properties
        end

        def replace_mixin_properties(props, additional_attributes = {})
          properties = ActiveSupport::HashWithIndifferentAccess.new

          props&.each do |key, value|
            if value.nil?
              properties.delete(key)
            elsif value[:type] == 'mixin'
              # deep reverse merge
              m_proc = ->(_, v1, v2) { v1.is_a?(::Hash) && v2.is_a?(::Hash) ? v1.merge(v2, &m_proc) : v1 }
              properties.merge!(replace_mixin_property(key, value[:name].to_sym, value.except(:name, :type)), &m_proc)
            else
              properties.deep_merge!({ key => value&.merge(additional_attributes) })
            end
          end

          properties.deep_reject! { |_, v| v.nil? }
          properties
        end

        def replace_mixin_property(key, property_name, additional_attributes)
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

          replace_mixin_properties(mixin[:properties], additional_attributes)
        end
      end
    end
  end
end
