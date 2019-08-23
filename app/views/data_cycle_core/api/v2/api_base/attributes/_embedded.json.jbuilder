# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  key_new = definition.dig('api', 'name') || key.camelize(:lower)
  json.set! key_new do
    if content.translations.size > 1 && @include_parameters.include?('translations')
      content.translations.each do |translation|
        I18n.with_locale(translation.locale) do
          json.set! translation.locale do
            translated_objects = content.send(key)
            json.array!(translated_objects.presence&.includes(:translations, :classifications)) do |translated_object|
              if translated_object.schema.present?
                json.content_partial! 'context', content: translated_object
                ordered_validation_properties(validation: translated_object.schema).each do |key, prop|
                  object_value = translated_object.try(key.to_sym)
                  partial_params = render_api_attribute key: key, definition: prop, value: object_value, parameters: { options: options }, content: translated_object
                  json.partial!(*partial_params) unless partial_params.nil?
                end
              end
            end
          end
        end
      end
    else
      json.array!(value.presence&.includes(:translations, :classifications)) do |object|
        I18n.with_locale(object.first_available_locale) do
          if object.schema.present?
            json.content_partial! 'context', content: object
            ordered_validation_properties(validation: object.schema).each do |key, prop|
              object_value = object.try(key.to_sym)
              partial_params = render_api_attribute key: key, definition: prop, value: object_value, parameters: { options: options }, content: object
              json.partial!(*partial_params) unless partial_params.nil?
            end
          end
        end
      end
    end
  end
end
