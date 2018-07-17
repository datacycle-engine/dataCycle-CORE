# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  if definition.dig('api', 'transformation', 'method') == 'unwrap'

    if content.translations.size > 1 && content.translatable_property_names.include?(key) && @include_parameters.include?('translations')
      ordered_validation_properties(validation: definition).each do |o_key, o_definition|
        o_key_name = o_definition.dig('api', 'name') || o_key
        json.set! o_key_name.camelize(:lower) do
          content.translations.each do |translation|
            I18n.with_locale(translation.locale) do
              json.set! translation.locale, content.try(key)&.try(o_key)
            end
          end
        end
      end
    else
      ordered_validation_properties(validation: definition).each do |o_key, o_definition|
        # json.render_attribute! key: o_key, definition: o_definition, value: value.try(o_key), parameters: { options: options }, content: content
        json.partial!(*(render_api_attribute key: o_key, definition: o_definition, value: value.try(o_key), parameters: { options: options }, content: content))
      end
    end

  else

    json.set! key.camelize(:lower) do
      json.set! '@type', definition.dig('api', 'type') if definition.dig('api', 'type').present?
      if content.translations.size > 1 && content.translatable_property_names.include?(key) && @include_parameters.include?('translations')
        ordered_validation_properties(validation: definition).each do |o_key, o_definition|
          o_key_name = o_definition.dig('api', 'name') || o_key
          json.set! o_key_name.camelize(:lower) do
            content.translations.each do |translation|
              I18n.with_locale(translation.locale) do
                json.set! translation.locale, content.try(key)&.try(o_key)
              end
            end
          end
        end
      else
        ordered_validation_properties(validation: definition).each do |o_key, o_definition|
          # json.render_attribute! key: o_key, definition: o_definition, value: value.try(o_key), parameters: { options: options }, content: content
          json.partial!(*(render_api_attribute key: o_key, definition: o_definition, value: value.try(o_key), parameters: { options: options }, content: content))
        end
      end
    end

  end
end
