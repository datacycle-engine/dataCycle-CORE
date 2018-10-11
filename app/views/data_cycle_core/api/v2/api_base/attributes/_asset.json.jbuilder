# frozen_string_literal: true

asset = value.first
if asset.present?
  json.set! key.camelize(:lower) do
    json.set! 'id', asset.id
    json.set! 'fileFormat', asset.content_type
    json.set! 'contentSize', asset.file_size
    json.set! 'url', File.join(root_url, asset.file.url)
    json.set! 'thumbnailUrl', File.join(root_url, asset.thumbnail_url) if asset.thumbnail_url?
  end
end
