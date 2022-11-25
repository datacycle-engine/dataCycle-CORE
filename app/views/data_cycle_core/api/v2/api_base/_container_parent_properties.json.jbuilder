# frozen_string_literal: true

if content&.parent&.content_type?('container') && options.dig(:disable_parent).blank?
  json.set! 'isPartOf' do
    json.content_partial! 'details', content: content.parent, options: options.merge({ disable_children: true })
  end
end
