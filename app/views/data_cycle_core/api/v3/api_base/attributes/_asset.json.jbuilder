# frozen_string_literal: true

render "data_cycle_core/api/v#{@api_version}/api_base/attribute", key: key, definition: definition, value: value, options: options, content: content do
  asset = value.first
  if asset.present?
    json.set! key.camelize(:lower) do
      json.set! 'id', asset.id
      json.set! 'fileFormat', asset.content_type
      json.set! 'contentSize', asset.file_size
      json.set! 'url', asset.file.url
      json.set! 'thumbnailUrl', asset.thumbnail_url if asset.thumbnail_url?
    end
  end
end
