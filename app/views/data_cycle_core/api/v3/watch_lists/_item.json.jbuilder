# frozen_string_literal: true

I18n.with_locale(item.hashable&.first_available_locale) do
  json.content_partial! 'details', content: item.hashable
end
