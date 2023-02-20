# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateTransformer
        attr_reader :template, :mixin_paths

        def initialize(template:, content_set: nil, mixins: nil)
          @template = template
          @content_set = content_set
          @mixins = mixins
          @mixin_paths = []
        end

        def main_config_property(key)
          DataCycleCore.main_config.dig(:templates, @content_set, @template[:name], key) || {}
        end

        def transform
          @template[:boost] ||= 1.0
          (@template[:features] ||= {}).deep_merge!(main_config_property(:features))
          @template[:properties] = transform_properties
          @template[:api] = main_config_property(:api).presence || @template[:api].presence || {}

          @template
        end

        def transform_properties
          new_properties = deep_transform_properties(@template)

          new_properties.deep_merge!(main_config_property(:properties))
          add_sorting_recursive!(new_properties)

          new_properties
        end

        def add_sorting_recursive!(properties)
          return properties if properties.blank?

          index = 0

          properties.each do |key, value|
            next properties.delete(key) if value.nil?

            value[:sorting] = index += 1

            properties.deep_reject! { |_, v| v.nil? }

            add_sorting_recursive!(value[:properties]) if value[:type] == 'object' && value.key?(:properties)
          end

          properties
        end

        def deep_transform_properties(template)
          properties = ActiveSupport::HashWithIndifferentAccess.new

          template[:properties].each do |key, value|
            next properties[key.to_sym] = value if value[:type] != 'mixin'

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

          @mixin_paths.push("#{@content_set}.#{@template[:name]}.#{property_name} => #{mixin[:path]}")

          deep_transform_properties(mixin)
        end
      end
    end
  end
end
