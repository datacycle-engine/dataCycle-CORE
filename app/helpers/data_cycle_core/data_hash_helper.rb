# frozen_string_literal: true

module DataCycleCore
  module DataHashHelper
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes + ['id']
    GROUP_FLAGS = [
      'collapsible',
      'squashed',
      'collapsed'
    ].freeze

    def object_from_definition(definition)
      return nil if definition.blank? || definition.dig('template_name').nil?

      template_name = definition['template_name']
      DataCycleCore::Thing.find_by("template = true AND schema ->> 'content_type' = ? AND template_name =?", 'entity', template_name)
    end

    def attribute_group_title(content, key)
      if I18n.exists?("attribute_labels.#{content&.template_name}.#{key.attribute_name_from_key}", locale: active_ui_locale)
        I18n.t("attribute_labels.#{content&.template_name}.#{key.attribute_name_from_key}", locale: active_ui_locale)
      elsif I18n.exists?("attribute_labels.#{key.attribute_name_from_key}", locale: active_ui_locale)
        I18n.t("attribute_labels.#{key.attribute_name_from_key}", locale: active_ui_locale)
      end
    end

    def ordered_validation_properties(validation:, type: nil, content_area: nil)
      return if validation.nil? || validation['properties'].blank?

      ordered_props = {}

      validation['properties'].sort_by { |_, prop| prop['sorting'] }.each do |key, prop|
        next if INTERNAL_PROPERTIES.include?(key) || prop['sorting'].blank?
        next if type.present? && prop['type'] != type
        next if content_area.presence&.!=('content') && prop.dig('ui', 'show', 'content_area') != content_area
        next if content_area == 'content' && prop.dig('ui', 'show', 'content_area').present?

        if (group = prop&.[]('ui')&.delete('attribute_group')).present? && content_area != 'header'
          group_name = group.remove(*GROUP_FLAGS.map { |f| "_#{f}" })
          ordered_props[group_name] ||= {
            'type' => 'attribute_group',
            'properties' => {},
            'features' => GROUP_FLAGS.index_with { |f| group.include?("_#{f}") }.compact_blank
          }

          ordered_props[group_name]['properties'][key] = prop
        else
          ordered_props[key] = prop
        end
      end

      ordered_props
    end

    def to_html_string(title, text = '')
      html_title = title.presence || ''
      html_title += ': ' if text.present?

      html_text = text.presence || ''

      out = []
      out << tag.i(html_title.html_safe)
      out << tag.b(html_text.html_safe)
      safe_join(out)
    end
  end
end
