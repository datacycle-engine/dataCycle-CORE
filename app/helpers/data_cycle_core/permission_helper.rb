# frozen_string_literal: true

module DataCycleCore
  module PermissionHelper
    def permission_type_string(type)
      description = type.to_descriptions.first
      Array.wrap(description[:restrictions]).join(', ')
    end

    def permission_groups(permissions)
      resolve_attribute_translations(permissions.flat_map(&:translated_descriptions))
        .sort_by { |d| [d[:permission], d[:action]] }
        .group_by { |d| d[:permission] }
        .transform_values do |v|
        v.group_by { |a| a[:action] }.transform_values do |a|
          a.filter { |p| p[:restrictions].present? }.uniq { |p| p[:restrictions] }
        end
      end
    end

    def resolve_attribute_translations(permissions)
      return permissions if permissions.pluck(:restrictions).flatten.none?(Abilities::AttributeTranslation)

      @property_translations ||= ThingTemplate.translated_property_names(locale: active_ui_locale)

      permissions.each do |permission|
        next if permission[:restrictions].flatten.none?(Abilities::AttributeTranslation)

        permission[:restrictions].map! do |r|
          resolve_attribute_translation(r, @property_translations)
        end
      end

      permissions
    end

    def resolve_attribute_translation(restriction, property_translations)
      if restriction.is_a?(::Array)
        restriction.map { |r| resolve_attribute_translation(r, property_translations) }.join(', ')
      elsif restriction.is_a?(Abilities::AttributeTranslation)
        restriction.resolve_keys(property_translations)
      else
        restriction
      end
    end

    def filtered_restrictions(action_restrictions)
      Array.wrap(action_restrictions).filter { |p| p[:restrictions].present? }.pluck(:restrictions, :segment)
    end
  end
end
