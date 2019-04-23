# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  key_name = definition.dig('api', 'name') || key
  json.set! key_name.camelize(:lower), value.to_h.values.map(&:iso8601).join('/') if value.present?
end
