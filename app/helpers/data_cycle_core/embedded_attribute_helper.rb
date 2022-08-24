# frozen_string_literal: true

module DataCycleCore
  module EmbeddedAttributeHelper
    def embedded_attribute_value(content, object, key, definition, locale, translate)
      return if object.template

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

    def embedded_add_button(id:, key:, content:, definition:, options: nil, **args)
      readonly = !attribute_editable?(key, definition, options, content)

      tag.button(id: id, type: 'button', class: 'button add-content-object', style: 'display: none;', disabled: readonly) do
        text = [tag.span(I18n.t('embedded.button_title', title: translated_attribute_label(key, definition, content, options), locale: active_ui_locale), class: 'add-content-object-text')]
        text.prepend(tag.i(class: 'fa fa-ban')) if readonly
        text.append(render('data_cycle_core/contents/quality_score', key: key, content: contextual_content({ content: content }.merge(args.slice(:parent))), definition: definition)) if definition.key?('quality_score')
        text.append(tag.i(class: 'fa fa-spinner fa-spin fa-fw'))
        safe_join(text)
      end
    end
  end
end
