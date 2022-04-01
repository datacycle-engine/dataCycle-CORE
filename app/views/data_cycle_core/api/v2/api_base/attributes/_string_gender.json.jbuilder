# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  key_name = definition.dig('api', 'name') || key
  value = [
    {
      '@type' => 'GenderType',
      'name' => value
    }
  ]
  json.set! key_name.camelize(:lower), value if value.present?
end
