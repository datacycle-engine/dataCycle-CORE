# frozen_string_literal: true

key_name = definition.dig('api', 'name') || key

json.set! '@type', definition.dig('api', 'type') if definition.dig('api', 'type').present?
json.set! 'identifier', key_name.camelize(:lower)
json.set! 'name', definition.dig('label')
json.set! 'unitCode', definition.dig('api', 'unit_code') if definition.dig('api', 'unit_code').present?
json.set! 'unitText', definition.dig('api', 'unit_text') if definition.dig('api', 'unit_text').present?
