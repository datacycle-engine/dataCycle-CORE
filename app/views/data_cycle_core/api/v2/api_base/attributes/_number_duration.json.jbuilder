# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  key_new = definition.dig('api', 'name') || key
  json.set! key_new.camelize(:lower), ((definition.dig('api', 'format', 'prepend') unless definition.dig('api', 'format', 'prepend').nil?) || '') + value.to_s + ((definition.dig('api', 'format', 'append') unless definition.dig('api', 'format', 'append').nil?) || '')
end
