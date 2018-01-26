json.contents @contents do |item|
  cache(item) do
    json.content_partial! 'details', content: item
  end
end

json.set! 'total', @total
