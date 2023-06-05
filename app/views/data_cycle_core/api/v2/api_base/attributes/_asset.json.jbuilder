# frozen_string_literal: true

render 'data_cycle_core/api/v2/api_base/attribute', key: key, definition: definition, value: value, options: options, content: content do
  asset = value
  if asset.present?
    key_new = definition.dig('api', 'name') || key

    json.set! key_new.camelize(:lower) do
      json.set! 'id', asset.id
      json.set! 'fileFormat', asset.content_type
      json.set! 'contentSize', asset.file_size
      json.set! 'url', asset.thing.content_url
      json.set! 'thumbnailUrl', asset.thing.thumbnail_url if asset.thing.try(:thumbnail_url)
    end
  end
end
