# frozen_string_literal: true

module DataCycleCore
  module EmbeddedAttributeHelper
    def embedded_attribute_value(content, object, key, definition, locale, translate)
      return if object.new_record?

      if translate && definition['type'] == 'string' && DataCycleCore::Feature::Translate.allowed?(content, I18n.locale, locale, current_user)
        source_locale = locale || object.first_available_locale
        translated_text = DataCycleCore::Feature::Translate.translate_text({
          'text' => I18n.with_locale(source_locale) { object.try(key.to_sym) },
          'source_locale' => source_locale.to_s,
          'target_locale' => I18n.locale.to_s
        })

        return if translated_text.try(:error).present?

        translated_text.dig('text')
      else
        I18n.with_locale(locale) { object.try(key.to_sym) }
      end
    end

    def embedded_editor_header(key:, content:, definition:, options: nil, **args)
      editable = attribute_editable?(key, definition, options, content)

      html = attribute_edit_label_tag(**args.merge(key:, content:, definition:, options:, i18n_count: 2))
      html << render('data_cycle_core/contents/viewers/shared/accordion_toggle_buttons', button_type: 'children')
      html << tag.button(tag.i(class: 'fa fa-plus'), id: "add_#{options&.dig(:prefix)}#{sanitize_to_id(key)}", type: 'button', class: 'button add-content-object', disabled: !editable) if editable

      tag.div(html, class: 'embedded-editor-header dc-sticky-bar')
    end

    def embedded_viewer_html_classes(**_args)
      'detail-type embedded-viewer embedded-wrapper'
    end
  end
end
