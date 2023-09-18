# frozen_string_literal: true

classification_aliases = content.send(key).includes(:classification_aliases).map(&:classification_aliases).flatten.uniq
if classification_aliases.present? && definition.dig('api', 'disabled').blank?
  key_new = definition.dig('api', 'name') || key.camelize(:lower)
  if definition.dig('api', 'transformation', 'method') == 'serialize' && definition.dig('api', 'transformation', 'name') == 'string'
    json.set! key_new do
      json.array!(classification_aliases) do |classification_alias|
        json.set! '@type', definition.dig('api', 'type') || 'Enumeration'
        json.set! 'name', classification_alias.description || classification_alias.name
      end
    end
  else
    json.partial! 'classifications', classification_aliases: classification_aliases, key: key_new
  end
end
