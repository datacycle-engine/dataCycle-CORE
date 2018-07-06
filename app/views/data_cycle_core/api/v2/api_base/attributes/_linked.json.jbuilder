# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  data = content.send(key).includes(:translations, :classifications)
  next if data.empty?

  json.set! key.camelize(:lower) do
    json.array!(data) do |item|
      if @include_parameters.include?('linked')
        json.cache!("#{item.class}_#{item.id}_#{item.updated_at}", expires_in: 24.hours + Random.rand(12.hours)) do
          json.content_partial! 'details', content: item
        end
      else
        json.content_partial! 'header', content: item, options: options.merge({ header_type: :linked })
      end
    end
  end
end
