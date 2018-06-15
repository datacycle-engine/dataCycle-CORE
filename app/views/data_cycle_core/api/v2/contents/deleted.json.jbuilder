# frozen_string_literal: true

json.contents @contents do |item|
  json.content_partial! 'deleted', content: item
end

json.set! 'total', @contents.total_count
