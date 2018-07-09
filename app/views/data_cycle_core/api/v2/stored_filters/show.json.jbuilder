# frozen_string_literal: true

json.data @contents do |item|
  json.cache!("#{item.class}_#{item.id}_#{@language}_#{item.updated_at}", expires_in: 24.hours + Random.rand(12.hours)) do
    I18n.with_locale(item.first_available_locale(@language.to_sym)) do
      json.content_partial! 'details', content: item
    end
  end
end

json.partial! 'pagination_links',
              objects: @pagination_contents || @contents,
              object_url: (lambda do |paging_params|
                File.join(request.protocol + request.host + ':' + request.port.to_s, request.path) + '?' +
                  @url_parameters.merge(paging_params).to_query
              end)
