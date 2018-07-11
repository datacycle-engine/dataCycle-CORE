# frozen_string_literal: true

json.cache!("#{@content.class}_#{@content.id}_#{@content.first_available_locale(@language.to_sym)}_#{@content.updated_at}_#{@include_parameters.join('_')}", expires_in: 24.hours + Random.rand(12.hours)) do
  I18n.with_locale(@content.first_available_locale(@language.to_sym)) do
    json.content_partial! 'details', content: @content
  end
end
