# frozen_string_literal: true

json.set! 'id', asset.id
json.set! 'fileFormat', asset.content_type
json.set! 'contentSize', asset.file_size
json.set! 'url', asset.file.url
json.set! 'thumbnailUrl', asset.thumbnail_url if asset.thumbnail_url?
