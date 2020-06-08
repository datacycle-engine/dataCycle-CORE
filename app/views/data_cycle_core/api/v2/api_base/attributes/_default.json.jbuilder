# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  key_new = definition.dig('api', 'name') || key
  if definition.dig('api', 'transformation', 'method') == 'nest' && definition.dig('api', 'transformation', 'name').present?
    json.set! definition.dig('api', 'transformation', 'name') do
      json.set! '@type', definition.dig('api', 'transformation', 'type') if definition.dig('api', 'transformation', 'type').present?
      if content.translations.size > 1 && content.translatable_property_names.include?(key) && @include_parameters.include?('translations')
        json.set! key_new.camelize(:lower) do
          content.translations.each do |translation|
            I18n.with_locale(translation.locale) do
              json.set! translation.locale, content.send(key)
            end
          end
        end
      else
        json.set! key_new.camelize(:lower), value
      end
    end
  elsif content.translations.size > 1 && content.translatable_property_names.include?(key) && @include_parameters.include?('translations')
    json.set! key_new.camelize(:lower) do
      content.translations.each do |translation|
        I18n.with_locale(translation.locale) do
          json.set! translation.locale, content.send(key)
        end
      end
    end
  else
    json.set! key_new.camelize(:lower), value
  end
end
