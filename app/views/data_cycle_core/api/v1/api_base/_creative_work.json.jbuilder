json.set! '@context', "http://www.schema.org/CreativeWork"

json.set! 'id', object.id
json.set! 'dateCreated', object.created_at
json.set! 'dateModified', object.updated_at

object.metadata.reject { |k, v| v.nil? || k == 'validation' }.each do |key, value|
  json.set! key, value
end

json.set! 'translations' do
  object.translations.each.each do |translation|
    json.set! translation.locale do
      Array(translation.content).each do |key, value|
        json.set! key, value
      end
      Array(translation.properties).each do |key, value|
        json.set! key, value
      end
    end
  end
end
