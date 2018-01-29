json.contents @contents do |item|
  json.cache!(item) do
    json.content_partial! 'details', content: item
  end
end

json.set! 'total', @total
