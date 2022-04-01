# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  generator = RGeo::WKRep::WKTGenerator.new({ tag_format: :wkt11 })
  key_new = definition.dig('api', 'name') || key
  if definition.dig('api', 'transformation', 'method') == 'nest' && definition.dig('api', 'transformation', 'name').present?
    json.set! definition.dig('api', 'transformation', 'name') do
      json.set! '@type', definition.dig('api', 'transformation', 'type') if definition.dig('api', 'transformation', 'type').present?
      json.set! key_new.camelize(:lower), generator.generate(value)
    end
  else
    json.set! key_new.camelize(:lower), generator.generate(value)
  end
end
