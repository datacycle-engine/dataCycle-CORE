@image.translated_locales.each do |language|
  I18n.with_locale(language) do
    data_hash = { "@context" => "http://www.schema.org/ImageObject", "@id" => @image.id }
    data_hash.merge!(@image.get_data_hash.compact)
    json.set! language, data_hash
  end
end
