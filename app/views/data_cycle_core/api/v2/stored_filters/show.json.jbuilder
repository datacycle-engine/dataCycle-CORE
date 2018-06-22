# frozen_string_literal: true

json.set! 'total', @total

json.contents @contents do |item|
  json.cache!("#{item.class}_#{item.id}_#{item.updated_at}", expires_in: 24.hours + Random.rand(12.hours)) do
    json.content_partial! 'details', content: item
  end
end
