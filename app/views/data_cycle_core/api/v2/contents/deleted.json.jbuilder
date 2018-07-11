# frozen_string_literal: true

json.data @contents do |item|
  json.content_partial! 'deleted', content: item
end

json.partial! 'pagination_links',
              objects: @contents,
              object_url: (lambda do |paging_params|
                File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' +
                  @url_parameters.merge(paging_params).to_query
              end)
