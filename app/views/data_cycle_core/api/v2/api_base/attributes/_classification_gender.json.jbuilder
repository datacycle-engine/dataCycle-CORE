# frozen_string_literal: true

concepts = content.send(key)
if concepts.present? && definition.dig('api', 'disabled').blank?
  key_new = definition.dig('api', 'name') || key.camelize(:lower)
  if definition.dig('api', 'transformation', 'method') == 'serialize' && definition.dig('api', 'transformation', 'name') == 'string'
    json.set! key_new do
      json.array!(concepts) do |concept|
        json.set! '@type', definition.dig('api', 'type') || 'Enumeration'
        json.set! 'name', concept.description || concept.name
      end
    end
  else
    json.partial! 'classifications', concepts: concepts, key: key_new
  end
end
