# frozen_string_literal: true

unless @mode_parameters.include?('compact')
  concepts = content.send(key)
  if concepts.present? && definition.dig('api', 'disabled').blank?
    key_new = definition.dig('api', 'name') || key.camelize(:lower)

    json.partial! 'data_cycle_core/api/v2/api_base/headers/property_value', key: key_new, definition: definition
    json.set! 'valueReference' do
      json.array!(concepts) do |concept|
        json.set! 'identifier', concept.id
        json.set! '@type', 'Enumeration'
        json.set! 'name', concept.name
      end
    end
  end
end
