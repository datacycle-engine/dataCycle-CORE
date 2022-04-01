# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  if value.to_h.present?
    value.to_h.each do |d|
      json.set! d[0].camelize(:lower), d[1]
    end
  end
end
