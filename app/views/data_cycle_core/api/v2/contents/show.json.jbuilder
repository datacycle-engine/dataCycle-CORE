# frozen_string_literal: true

json.cache!("#{@content.class.to_s}_#{@content.id}_#{@content.updated_at.to_s}", expires_in: 24.hours + Random.rand(12.hours)) do
  json.content_partial! 'details', content: @content
end
