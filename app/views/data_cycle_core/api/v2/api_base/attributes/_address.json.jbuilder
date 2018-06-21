# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  json.set! key.camelize(:lower) do
    if value.to_h.present?
      json.set! '@type', 'PostalAddress'
      value.to_h.each do |d|
        json.set! d[0], d[1]
      end
    end
  end
end
