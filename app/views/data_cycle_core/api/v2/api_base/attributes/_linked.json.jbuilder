# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  data = content.send(key).includes(:translations, :classifications)
  next if data.empty?

  json.set! key.pluralize.camelize(:lower) do
    json.array!(data) do |item|
      json.cache!("#{item.class}_#{item.id}_#{item.updated_at}", expires_in: 24.hours + Random.rand(12.hours)) do
        json.content_partial! 'details', content: item
      end
    end
  end
end
