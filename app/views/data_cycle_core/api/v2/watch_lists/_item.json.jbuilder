# frozen_string_literal: true

I18n.with_locale(item.thing&.first_available_locale) do
  json.content_partial! 'details', content: item.thing
end
