# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  if content.translations.size > 1 && content.translatable_property_names.include?(key)
    json.set! key.camelize(:lower) do
      content.translations.each do |translation|
        I18n.with_locale(translation.locale) do
          json.set! translation.locale, content.send(key)
        end
      end
    end
  else
    json.set! key.camelize(:lower), value
  end
end
