default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes +  ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})


json.content_partial! 'header', content: content, options: options

options[:hidden_attributes] += [
    'latitude',  'longitude',  'elevation', 'location',
    'addressLocality', 'streetAddress', 'postalCode', 'addressCountry'  
]

json.partial! 'untranslated_properties', content: content, locale: content.translations.first.locale, options: options

if (!['addressLocality', 'streetAddress', 'postalCode', 'addressCountry'].map { |k| content.send(k) }.join.blank?)
  json.set! 'address' do
    json.partial! 'address', addressData: content
  end
end

if (content.latitude && content.longitude) || content.elevation
  json.set! 'geo' do
    json.partial! 'geo', geoData: content
  end
end

if content.translations.size == 1 
  json.set! 'inLanguage', content.translations.first.locale
  json.partial! 'translated_properties', content: content, locale: content.translations.first.locale, options: options
else
  json.set! 'translations' do
    content.translations.each do |translation|
      json.set! translation.locale do
        json.partial! 'translated_properties', content: content, locale: translation.locale, options: options
      end
    end
  end
end

json.partial! 'linked_properties', content: content, options: options

json.partial! 'embedded_properties', content: content, options: options