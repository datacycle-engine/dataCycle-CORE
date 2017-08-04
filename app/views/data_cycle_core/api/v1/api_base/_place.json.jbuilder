json.partial! 'preface', object: object

special_attributes = DataCycleCore.special_data_attributes + [
  'id', 'external_source_id', 'external_key', 'validation',
  'seen_at', 'created_at', 'updated_at',
  'address', 'addressLocality', 'streetAddress', 'postalCode', 'addressCountry', 
  'latitude',  'longitude',  'elevation', 'location',
  'metadata', 'content', 'properties', 'template'
]

if object.streetAddress || object.postalCode || object.addressLocality || object.addressCountry
  json.set! 'address' do
    json.partial! 'address', addressData: object
  end
end

if (object.latitude && object.longitude) || object.elevation
  json.set! 'geo' do
    json.set! '@type', 'GeoCoordinates'
    json.set! 'latitude', object.latitude if object.latitude && object.longitude
    json.set! 'longitude', object.longitude if object.latitude && object.longitude
    json.set! 'elevation', object.elevation if object.elevation
  end
end

object.metadata.reject { |k, v| v.blank? || special_attributes.include?(k) }.each do |key, value|
  json.set! key, value
end

object.attributes.reject { |k, v| v.blank? || special_attributes.include?(k) }.each do |key, value|
  json.set! key, value
end

json.set! 'translations' do
  object.translations.each.each do |translation|
    json.set! translation.locale do
      if translation.streetAddress || translation.postalCode || translation.addressLocality || translation.addressCountry
        json.set! 'address' do
          json.partial! 'address', addressData: translation
        end
      end

      translation.attributes.reject { |k, v| v.nil? || (special_attributes + ['place_id', 'locale']).include?(k) }.each do |key, value|
        json.set! key, value
      end

      Array(translation.content).reject { |k, v| v.nil? || (special_attributes + ['place_id', 'locale']).include?(k) }.each do |key, value|
        json.set! key, value
      end

      Array(translation.properties).reject { |k, v| v.nil? || (special_attributes + ['place_id', 'locale']).include?(k) }.each do |key, value|
        json.set! key, value
      end
    end
  end
end
