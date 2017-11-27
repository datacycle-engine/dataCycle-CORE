json.contents @contents do |item|
  json.content_partial! 'details', content: item
end

json.set! 'total', @total
