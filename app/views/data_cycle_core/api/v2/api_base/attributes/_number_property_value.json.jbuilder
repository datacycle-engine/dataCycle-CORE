# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  if definition.dig('api', 'transformation', 'method') == 'nest' && definition.dig('api', 'transformation', 'name').present?
    json.set! definition.dig('api', 'transformation', 'name') do
      json.partial! 'data_cycle_core/api/v2/api_base/headers/property_value', key: key, definition: definition

      if content.translations.size > 1 && content.translatable_property_names.include?(key) && @include_parameters.include?('translations')
        json.set! 'value' do
          content.translations.each do |translation|
            I18n.with_locale(translation.locale) do
              json.set! translation.locale, content.send(key)
            end
          end
        end
      else
        json.set! 'value', value
      end
    end
  elsif content.schema.dig('content_type') == 'entity' || options.dig(:content_type) == 'linked'
    json.partial! 'data_cycle_core/api/v2/api_base/headers/property_value', key: key, definition: definition

    if content.translations.size > 1 && content.translatable_property_names.include?(key) && @include_parameters.include?('translations')
      json.set! 'value' do
        content.translations.each do |translation|
          I18n.with_locale(translation.locale) do
            json.set! translation.locale, content.send(key)
          end
        end
      end
    else
      json.set! 'value', value
    end
  else # fallback to regular key/value
    key_name = definition.dig('api', 'name') || key
    json.set! key_name.camelize(:lower), value
  end
end
