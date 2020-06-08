# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  data = content.send(key).includes(:translations, :classifications)
  next if data.empty?

  key_new = definition.dig('api', 'name') || key.camelize(:lower)
  json.set! key_new do
    json.array!(data) do |item|
      json.content_partial! 'details', content: item, options: { content_type: 'linked' }
    end
  end
end
