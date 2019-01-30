# frozen_string_literal: true

unless @mode_parameters.include?('compact')
  classification_aliases = content.send(key).includes(:classification_aliases).map(&:classification_aliases).flatten.uniq
  if classification_aliases.present? && definition.dig('api', 'disabled').blank?
    key_new = definition.dig('api', 'name') || key.camelize(:lower)
    json.set! key_new, classification_aliases.map(&:name).join(',')
  end
end
