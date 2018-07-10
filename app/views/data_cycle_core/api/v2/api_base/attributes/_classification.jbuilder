# frozen_string_literal: true

classification_aliases = content.send(key).includes(:classification_aliases).map(&:classification_aliases).flatten.uniq
if classification_aliases.present?
  key_new = definition.dig('api', 'name') || key.camelize(:lower)
  json.partial! 'classifications', classification_aliases: classification_aliases, key: key_new
end
