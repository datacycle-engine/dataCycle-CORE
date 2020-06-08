# frozen_string_literal: true

json.cache!(api_cache_key(@content, @language, @include_parameters, @mode_parameters, @api_subversion), expires_in: 1.year + Random.rand(7.days)) do
  I18n.with_locale(@content.first_available_locale(@language)) do
    json.content_partial! 'details', content: @content
  end
end
