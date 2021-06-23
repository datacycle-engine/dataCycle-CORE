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
  end
end
