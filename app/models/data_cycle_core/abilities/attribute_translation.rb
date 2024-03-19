# frozen_string_literal: true

module DataCycleCore
  module Abilities
    AttributeTranslation = Struct.new(:keys, :template_name, :translation_function) do
      def resolve_keys(property_translations)
        data = if keys.any?(Array)
                 transform_key_path(keys, property_translations)
               else
                 attributes(property_translations, template_name).pluck(*keys).flatten.compact.pluck(:text).uniq.join(', ')
               end

        if translation_function.parameters.size == 2
          translation_function.call(data, template_name)
        else
          translation_function.call(data)
        end
      end

      def transform_key_path(keys, property_translations)
        keys.map { |path|
          if path.is_a?(::Array)
            allowed_templates = Array.wrap(template_name&.to_s)
            path_t = path.map do |p|
              filtered_a = attributes(property_translations, allowed_templates)
                .pluck(p).compact
              filtered_a = filtered_a.filter { |a| a[:type] == 'embedded' } unless p == path.last
              allowed_templates = filtered_a.pluck(:template).compact
              filtered_a.pluck(:text).uniq
            end

            path_t[0].product(*path_t[1..-1]).map { |p| p.join(' -> ') }
          else
            attributes(property_translations, template_name).pluck(path).compact.pluck(:text).uniq
          end
        }.flatten.uniq.join(', ')
      end

      def attributes(property_translations, templates)
        allowed = property_translations
        allowed = allowed.slice(*Array.wrap(templates)) if templates.present?
        allowed_attributes = allowed.values.flatten
        allowed_attributes.reject! { |value| value.any? { |_, v| v[:embedded_template] } } if templates.blank?
        allowed_attributes
      end
    end
  end
end
