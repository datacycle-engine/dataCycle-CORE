# frozen_string_literal: true

module DataCycleCore
  module UiLocaleHelper
    def active_ui_locale
      current_user&.ui_locale || DataCycleCore.ui_locales.first
    rescue StandardError
      DataCycleCore.ui_locales.first
    end

    def available_locales_with_names
      @available_locales_with_names ||= Hash.new do |h, key|
        h[key] = I18n
          .t('locales', locale: key)
          .slice(*I18n.available_locales)
          .transform_values(&:capitalize)
          .sort_by { |_, v| v.to_s }
          .to_h
      end

      @available_locales_with_names[active_ui_locale]
    end

    def available_locales_with_all
      @available_locales_with_all ||= Hash.new do |h, key|
        if I18n.available_locales&.many?
          h[key] = available_locales_with_names.reverse_merge({ all: t('common.all', locale: active_ui_locale) })
        else
          h[key] = available_locales_with_names
        end
      end

      @available_locales_with_all[active_ui_locale]
    end

    def translated_attribute_label(key, definition, content, options, count = 1)
      I18n.with_locale(active_ui_locale) do
        DataCycleCore::Thing.human_property_name(key.attribute_name_from_key.to_s, (options || {}).merge({ base: content, count: count, definition: definition }))
      end
    end

    def object_has_translatable_attributes?(content, definition)
      return unless definition&.dig('type') == 'object'

      definition['properties']&.any? { |k, v| attribute_translatable?(k, v, content) }
    end

    def attribute_translatable?(key, definition, content)
      content&.attribute_translatable?(key.attribute_name_from_key, definition)
    end

    def attribute_viewer_label_tag(key:, definition:, content:, options: nil, accordion_controls: false, i18n_count: 1, **args)
      label_html = ActionView::OutputBuffer.new(tag.span(translated_attribute_label(key, definition, content, options, i18n_count), class: 'attribute-label-text', title: translated_attribute_label(key, definition, content, options, i18n_count)))

      label_html.prepend(tag.i(class: 'fa fa-language translatable-attribute-icon')) if attribute_translatable?(key, definition, content)
      label_html.prepend(tag.i(class: "dc-type-icon property-icon key-#{key.attribute_name_from_key} type-#{definition&.dig('type')} #{"type-#{definition&.dig('type')}-#{definition.dig('ui', 'show', 'type')}" if definition&.dig('ui', 'show', 'type').present?}"))
      label_html << render('data_cycle_core/contents/content_score', key: key, content: contextual_content({ content: content }.merge(args.slice(:parent))), definition: definition) if definition.key?('content_score')
      label_html << render('data_cycle_core/contents/viewers/shared/accordion_toggle_buttons', button_type: 'children') if accordion_controls

      tag.span label_html, class: 'detail-label'
    end

    def attribute_edit_label_tag(key:, definition:, content:, options:, html_classes: nil, i18n_count: 1, **args)
      label_html = ActionView::OutputBuffer.new(tag.span(translated_attribute_label(key, definition, content, options, i18n_count), class: 'attribute-label-text', title: translated_attribute_label(key, definition, content, options, i18n_count)))

      label_html.prepend(tag.i(class: 'fa fa-language translatable-attribute-icon')) if attribute_translatable?(key, definition, content)
      label_html.prepend(tag.i(class: "dc-type-icon property-icon key-#{key.attribute_name_from_key} type-#{definition&.dig('type')} #{"type-#{definition&.dig('type')}-#{definition.dig('ui', 'edit', 'type')}" if definition&.dig('ui', 'edit', 'type').present?}"))
      label_html.prepend(tag.i(class: 'fa fa-ban', aria_hidden: true)) unless attribute_editable?(key, definition, options, content)
      label_html << render('data_cycle_core/contents/helper_text', key: key, content: contextual_content({ content: content }.merge(args.slice(:parent))), definition: definition)
      label_html << render('data_cycle_core/contents/content_score', key: key, content: contextual_content({ content: content }.merge(args.slice(:parent))), definition: definition) if definition.key?('content_score')

      label_tag "#{options&.dig(:prefix)}#{sanitize_to_id(key)}", label_html, class: "attribute-edit-label #{html_classes}".strip
    end

    def content_score_tooltip(definition)
      tooltip_html = [t('feature.content_score.tooltip.title_html', locale: active_ui_locale)]

      tooltip_html.push(t('feature.content_score.tooltip.min', value: definition.dig('content_score', 'score_matrix', 'min'), locale: active_ui_locale)) if definition.dig('content_score', 'score_matrix', 'min').present?
      tooltip_html.push(t('feature.content_score.tooltip.optimal', value: definition.dig('content_score', 'score_matrix', 'optimal'), locale: active_ui_locale)) if definition.dig('content_score', 'score_matrix', 'optimal').present?
      tooltip_html.push(t('feature.content_score.tooltip.max', value: definition.dig('content_score', 'score_matrix', 'max'), locale: active_ui_locale)) if definition.dig('content_score', 'score_matrix', 'max').present?

      tooltip_html.join('<br>')
    end
  end
end
