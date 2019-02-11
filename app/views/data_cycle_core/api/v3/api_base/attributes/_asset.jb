# frozen_string_literal: true

json ||= {}
asset = value.first
if asset.present?
  json[key.camelize(:lower)] = {
    id: asset.id,
    fileFormat: asset.content_type,
    contentSize: asset.file_size,
    url: asset.file.url
  }
  json[key.camelize(:lower)]['thumbnailUrl'] = asset.thumbnail_url if asset.thumbnail_url?
end
json
