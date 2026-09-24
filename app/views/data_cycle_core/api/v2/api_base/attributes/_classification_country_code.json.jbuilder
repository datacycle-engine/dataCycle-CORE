# frozen_string_literal: true

concepts = content.send(key)
if concepts.present? && definition.dig('api', 'disabled').blank?
  json.set! 'address' do
    json.set! 'addressCountry', concepts.first.name
  end
end
