# frozen_string_literal: true

json.cache!("#{@content.class}_#{@content.id}_#{@content.updated_at}", expires_in: 24.hours + Random.rand(12.hours)) do
  json.content_partial! 'details', content: @content
end
