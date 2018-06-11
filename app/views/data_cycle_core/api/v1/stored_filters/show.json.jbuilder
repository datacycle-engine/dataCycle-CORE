# frozen_string_literal: true

json.set! 'total', @total

json.contents @contents do |item|
  json.cache!(item) do
    json.content_partial! 'details', content: item
  end
end
