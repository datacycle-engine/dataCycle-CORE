def storage_cases_get(image, key, properties, translated)
  case properties["storage_location"]
  when "column"
    image.method(key).call if image.translated_attribute_names.include?(key) == translated
  when "content"
    image.content[key] if translated
  when "metadata"
    image.metadata[key] if !translated
  when "properties"
    image.properties[key] if translated
  when "classification_relation"
    # no classification_links for now (are split in different fields)
    #get_relation_ids(properties["storage_type"], properties["type_name"]) if !translated
  when "key"
    image.id if !translated
  #else
    # no embedded data for now
    # get_linked_data_type(properties['storage_location'], properties['name'], properties['description'])
  end
end


data_type = image.metadata['validation']

# non translated items
json.set! "@context", "http://www.schema.org/ImageObject"
data_type['properties'].each do |key,value|
   data = storage_cases_get(image, key, value, false)
   json.set! key, data unless data.blank?
end
class_hash = []
image.classification_aliases.each do |class_item|
  class_hash.push({"id" => class_item.id, name: class_item.name})
end
json.set! "classifications_aliases", class_hash


# get translated items
data_hash_trans = {}
image.translated_locales.each do |language|
  data_hash_lang = {}
  I18n.with_locale(language) do
    data_type['properties'].each do |key,value|
      data_hash_lang[key] = storage_cases_get(image, key, value, true)
    end
  end
  data_hash_trans[language] = data_hash_lang.compact
end
json.set! "translations", data_hash_trans
