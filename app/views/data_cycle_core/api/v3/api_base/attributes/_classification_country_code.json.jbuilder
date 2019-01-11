# frozen_string_literal: true

classification_aliases = content.send(key).includes(:classification_aliases).map(&:classification_aliases).flatten.uniq
if classification_aliases.present? && definition.dig('api', 'disabled').blank?
  json.set! 'address' do
    json.set! 'addressCountry', classification_aliases.first.name
  end
end
