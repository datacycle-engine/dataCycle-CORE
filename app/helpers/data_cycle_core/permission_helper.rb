# frozen_string_literal: true

module DataCycleCore
  module PermissionHelper
    def permission_type_string(type)
      description = type.to_descriptions.first

      return "translation missing: abilities.restrictions.#{type.class.name.demodulize.underscore}" if description[:restrictions].blank?

      Array.wrap(description[:restrictions]).join(', ')
    end

    def permission_groups(permissions)
      resolve_attribute_translations(permissions.flat_map(&:translated_descriptions))
        .sort_by { |d| "#{I18n.transliterate(d[:permission].downcase, locale: active_ui_locale)} - #{I18n.transliterate(d[:action].downcase, locale: active_ui_locale)}" }
        .group_by { |d| d[:permission] }
        .transform_values do |v|
          v.group_by { |a| a[:action] }
            .transform_values do |a|
            next [] if a.any? { |r| r[:restrictions].blank? }
            Array.wrap(a.pluck(:restrictions)).compact_blank.uniq
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
  end
end
