# frozen_string_literal: true

module DataCycleCore
  module UiLocaleHelper
    def active_ui_locale
      current_user&.ui_locale || DataCycleCore.ui_locales.first
    end

    def translated_attribute_label(key, definition, content, options)
      @translated_attribute_label ||= Hash.new do |h, k|
        h[k] = begin
          if I18n.exists?("attribute_labels.#{k[3]}.#{k[2]}.#{k[0]}")
            I18n.t("attribute_labels.#{k[3]}.#{k[2]}.#{k[0]}", locale: k[4])
          elsif I18n.exists?("attribute_labels.#{k[2]}.#{k[0]}")
            I18n.t("attribute_labels.#{k[2]}.#{k[0]}", locale: k[4])
          elsif I18n.exists?("attribute_labels.#{k[3]}.#{k[0]}")
            I18n.t("attribute_labels.#{k[3]}.#{k[0]}", locale: k[4])
          elsif I18n.exists?("attribute_labels.#{k[0]}")
            I18n.t("attribute_labels.#{k[0]}", locale: k[4])
          elsif k[1].present?
            k[1].dig('ui', k[3].to_s, 'label') || k[1]['label']
          else
            k[0].titleize
          end
        end
      end

      @translated_attribute_label[[
        key.attribute_name_from_key,
        definition,
        content&.template_name,
        options&.dig(:ui_scope),
        active_ui_locale
      ]]
    end

    def attribute_edit_label_tag(key, definition, content, options)
      label_html = ActionView::OutputBuffer.new(tag.span(translated_attribute_label(key, definition, content, options), class: 'attribute-label-text'))

      if content.try(:translatable_property?, key.attribute_name_from_key, definition) && content.translatable? && I18n.available_locales&.many?
        label_html.prepend(tag.i(class: 'fa fa-language translatable-attribute-icon'))
        label_html << tag.span("(#{I18n.locale})", class: 'attribute-locale')
      end

      label_html.prepend(tag.i(class: "dc-type-icon property-icon key-#{key.attribute_name_from_key} type-#{definition&.dig('ui', 'edit', 'type') || definition&.dig('type')}"))
      label_html.prepend(tag.i(class: 'fa fa-ban', aria_hidden: true)) unless attribute_editable?(key, definition, options, content)
      label_html << render('data_cycle_core/contents/helper_text', key: key, content: content, definition: definition)

      label_tag "#{options&.dig(:prefix)}#{sanitize_to_id(key)}", label_html, class: 'attribute-edit-label'
    end
  end
end
