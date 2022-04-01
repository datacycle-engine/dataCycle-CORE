# frozen_string_literal: true

json.contents @contents do |item|
  json.cache!(api_cache_key(item, I18n.locale, [], []), expires_in: 24.hours + Random.rand(12.hours)) do
    json.content_partial! 'details', content: item
  end
end

json.partial! 'pagination_links',
              objects: @contents,
              object_url: (lambda do |paging_params|
                File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' +
                  @url_parameters.merge(paging_params).to_query
              end)
