json.contents @contents do |item|
  json.content_partial! 'deleted', content: item
end

json.set! 'total', @total
