# frozen_string_literal: true

def render_targets(value, definition, json)
  json.array!([value]) do |item|
    json.set! '@type', 'EntryPoint'
    json.set! 'urlTemplate', item
    json.set! 'actionPlatform', definition.dig('api', 'action', 'platform') if definition.dig('api', 'action', 'platform').present?
  end
end

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  json.partial! 'data_cycle_core/api/v2/api_base/headers/action', key: key, definition: definition

  if content.translations.size > 1 && content.translatable_property_names.include?(key) && @include_parameters.include?('translations')
    json.set! 'target' do
      content.translations.each do |translation|
        I18n.with_locale(translation.locale) do
          json.set! translation.locale do
            render_targets(content.send(key), definition, json)
          end
        end
      end
    end
  else
    json.set! 'target' do
      render_targets(value, definition, json)
    end
  end
end
