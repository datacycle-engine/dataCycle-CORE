# frozen_string_literal: true

unless @mode_parameters.include?('compact')
  concepts = content.send(key)
  if concepts.present? && definition.dig('api', 'disabled').blank?
    key_new = definition.dig('api', 'name') || key.camelize(:lower)
    json.set! key_new, concepts.map(&:name).join(',')
  end
end
