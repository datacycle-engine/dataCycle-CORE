# frozen_string_literal: true

json.contents @contents do |item|
  json.cache!(api_cache_key(item, I18n.locale, [], []), expires_in: 24.hours + Random.rand(12.hours)) do
    json.content_partial! 'details', content: item
  end
end

json.set! 'total', @total
