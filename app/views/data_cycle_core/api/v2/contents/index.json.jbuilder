# frozen_string_literal: true

json.data @contents do |item|
  json.cache!(api_cache_key(item, @language, @include_parameters, @mode_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
    I18n.with_locale(item.first_available_locale(@language)) do
      json.content_partial! 'details', content: item
    end
  end
end

json.partial! 'pagination_links',
              objects: @pagination_contents || @contents,
              object_url: (lambda do |params|
                File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' + params.to_query
              end)
