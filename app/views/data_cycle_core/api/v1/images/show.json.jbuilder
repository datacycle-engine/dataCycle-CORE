begin
  json.partial! 'creative_work_bild', object: @image
rescue
  json.partial! 'creative_work', object: @image
end
