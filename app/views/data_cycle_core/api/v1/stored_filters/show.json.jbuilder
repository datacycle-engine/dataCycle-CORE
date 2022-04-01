# frozen_string_literal: true

json.set! 'total', @total

json.contents @contents do |item|
  json.cache!(api_cache_key(item, I18n.locale, [], [])) do
    json.content_partial! 'details', content: item
  end
end
