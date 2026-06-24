# frozen_string_literal: true

module DataCycleCore
  module EmbeddedAttributeHelper
    def embedded_attribute_value(content, object, key, definition, locale, translate)
      return I18n.with_locale(locale) { object.default_value(key.attribute_name_from_key, current_user, {}) } if object.new_record? && !object.generic_template?

      if translate && definition['type'] == 'string' && DataCycleCore::Feature['Translate']&.allowed?(content, I18n.locale, locale, current_user)
        source_locale = locale || object.first_available_locale
        translated_text = DataCycleCore::Feature['Translate'].translate_text({
          'text' => I18n.with_locale(source_locale) { object.try(key.to_sym) },
          'source_locale' => source_locale.to_s,
          'target_locale' => I18n.locale.to_s
        })

        return if translated_text.try(:error).present?

        translated_text['text']
      else
        I18n.with_locale(locale) { object.try(key.to_sym) }
      end
    end

    def embedded_editor_header(key:, content:, definition:, options: nil, **args)
      editable = attribute_editable?(key, definition, options, content)

      html = attribute_edit_label_tag(**args, key:, content:, definition:, options:, i18n_count: 2)
      html << render('data_cycle_core/contents/viewers/shared/accordion_toggle_buttons', button_type: 'children')

      if editable
        html << if definition&.dig('template_name').is_a?(Array)
                  render('data_cycle_core/contents/editors/embedded/new_partials/new_content_button', id: "add_#{options&.dig(:prefix)}#{sanitize_to_id(key)}", templates: definition['template_name'].map { |t| DataCycleCore::DataHashService.get_internal_template(t) })
                else
                  tag.div(tag.button(tag.i(class: 'fa fa-plus'), id: "add_#{options&.dig(:prefix)}#{sanitize_to_id(key)}", type: 'button', class: 'button add-content-object', disabled: !editable, data: { template: definition['template_name'] }), class: 'new-embedded-button-wrapper')
                end
      end

      tag.div(html, class: 'embedded-editor-header dc-sticky-bar')
    end

    def embedded_viewer_html_classes(**_args)
      'detail-type embedded-viewer embedded-wrapper'
    end

    # return locales to be rendered inline for the given key, depending on the type of embedded (translatable or not)
    def force_render_locales_for_key(object, local_assigns = {})
      return local_assigns[:force_render_locales] if local_assigns.key?(:force_render_locales)

      content = contextual_content(local_assigns)
      key = local_assigns[:key]&.attribute_name_from_key

      return [] if content.translatable_property?(key)

      object.available_locales
    end

    # return locales that are allowed to be rendered for the given key, depending on the type of embedded (translatable or not)
    def allowed_embedded_locales_for_key(local_assigns = {})
      content = contextual_content(local_assigns)
      key = local_assigns[:key]&.attribute_name_from_key

      return [I18n.locale] if content.translatable_property?(key)
      return local_assigns[:allowed_locales]&.map(&:to_sym) if local_assigns.key?(:allowed_locales)

      I18n.available_locales
    end

    def parsed_allowed_locales(local_assigns = {})
      local_assigns.dig(:parameters, :allowed_locales)&.map(&:to_sym).presence ||
        I18n.available_locales
    end
  end
end
