# frozen_string_literal: true

module DataCycleCore
  module DataHashHelper
    INTERNAL_PROPERTIES = DataCycleCore.internal_data_attributes + ['id']
    GROUP_FLAGS = [
      'collapsible',
      'one_line',
      'collapsed',
      'two_columns',
      'three_columns',
      'four_columns'
    ].freeze

    def object_from_definition(definition)
      return nil if definition.blank? || definition.dig('template_name').nil?

      template_name = definition['template_name']
      DataCycleCore::Thing.find_by("template = true AND schema ->> 'content_type' = ? AND template_name =?", 'entity', template_name)
    end

    def attribute_group_title(content, key)
      label_html = ActionView::OutputBuffer.new

      if I18n.exists?("attribute_labels.#{content&.template_name}.#{key.attribute_name_from_key}", locale: active_ui_locale)
        label_html << tag.span(I18n.t("attribute_labels.#{content&.template_name}.#{key.attribute_name_from_key}", locale: active_ui_locale))
      elsif I18n.exists?("attribute_labels.#{key.attribute_name_from_key}", locale: active_ui_locale)
        label_html << tag.span(I18n.t("attribute_labels.#{key.attribute_name_from_key}", locale: active_ui_locale))
      else
        return
      end

      label_html.prepend(tag.i(class: "dc-type-icon property-icon key-#{key.attribute_name_from_key} type-object"))
      label_html << render('data_cycle_core/contents/helper_text', key: key, content: content)

      label_html
    end

    def ordered_validation_properties(validation:, type: nil, content_area: nil, scope: :edit)
      return if validation.nil? || validation['properties'].blank?

      ordered_props = {}

      validation['properties'].sort_by { |_, prop| prop['sorting'] }.each do |key, prop|
        next if INTERNAL_PROPERTIES.include?(key) || prop['sorting'].blank?
        next if type.present? && prop['type'] != type
        next if content_area.presence&.!=('content') && prop.dig('ui', scope.to_s, 'content_area') != content_area
        next if content_area == 'content' && prop.dig('ui', scope.to_s, 'content_area').present?

        add_attribute_config(key, prop, scope, content_area, ordered_props)
      end

      ordered_props
    end

    def add_attribute_config(key, prop, scope, content_area, ordered_props)
      return ordered_props[key] = prop unless content_area != 'header' && (prop['ui']&.key?('attribute_group') || prop.dig('ui', scope.to_s)&.key?('attribute_group'))

      cloned_props = prop.deep_dup
      cloned_props['ui'].delete('attribute_group') if cloned_props['ui']&.key?('attribute_group') && cloned_props.dig('ui', scope.to_s)&.key?('attribute_group')

      prop_context = cloned_props.dig('ui', scope.to_s)&.key?('attribute_group') ? cloned_props['ui'][scope.to_s] : cloned_props['ui']
      group = prop_context.then { |g| g['attribute_group'].is_a?(::Array) ? g['attribute_group'].shift : g.delete('attribute_group') }
      prop_context.delete('attribute_group') if prop_context.key?('attribute_group') && prop_context['attribute_group'].blank?
      group_name = group.remove(*GROUP_FLAGS.map { |f| "_#{f}" })

      ordered_props[group_name] ||= {
        'type' => 'attribute_group',
        'properties' => {},
        'features' => GROUP_FLAGS.index_with { |f| group.include?("_#{f}") }.compact_blank
      }

      ordered_props[group_name]['properties'][key] = cloned_props
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
