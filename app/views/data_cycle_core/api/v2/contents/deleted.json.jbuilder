# frozen_string_literal: true

json.data @contents do |item|
  json.content_partial! 'deleted', content: item
end

json.partial! 'pagination_links',
              objects: @contents,
              object_url: ->(params) { File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' + params.to_query }
