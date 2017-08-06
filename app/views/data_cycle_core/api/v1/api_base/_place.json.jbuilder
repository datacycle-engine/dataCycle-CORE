type = object.metadata['validation']['name']

begin
  json.partial! "#{object.class.class_name.underscore}_#{type.underscore}", object: object, nested: defined?(nested) ? nested : false
rescue ActionView::MissingTemplate => e
  logger.info "Using standard template for #{object.class.to_s} - #{type}"

  json.partial! 'header', object: object

  object = DataCycleCore::ContentDecorator.new(object)

  special_attributes = DataCycleCore.special_data_attributes +  DataCycleCore::ContentDecorator.special_property_names + [
    'latitude',  'longitude',  'elevation', 'location',
    'addressLocality', 'streetAddress', 'postalCode', 'addressCountry'
  ]

  if (object.latitude && object.longitude) || object.elevation
    json.set! 'geo' do
      json.set! '@type', 'GeoCoordinates'
      json.set! 'latitude', object.latitude if object.latitude && object.longitude
      json.set! 'longitude', object.longitude if object.latitude && object.longitude
      json.set! 'elevation', object.elevation if object.elevation
    end
  end

  ((object.untranslatable_property_names & object.plain_property_names) - special_attributes).each do |key|
    json.set! key, object.property_value(key) unless object.property_value(key).blank?
  end

  if object.translations == 1 
    translation = object.translations.first

    json.set! 'inLanguage', translation.locale

    (object.translatable_property_names - special_attributes).each do |key|
      json.set! key, object.property_value(key) unless object.property_value(key).blank?
    end

    json.set! 'address' do
      json.partial! 'address', addressData: translation
    end
  else
    json.set! 'translations' do
      object.translations.each do |translation|
        json.set! translation.locale do
          (object.translatable_property_names - special_attributes).each do |key|
            json.set! key, object.property_value(key) unless object.property_value(key).blank?
          end

          json.set! 'address' do
            json.partial! 'address', addressData: translation
          end
        end
      end
    end
  end

  object.linked_object_definitions.each do |k, v|
    json.partial! v['type'].underscore, name: k, definition: v, data: object.linked_object_data(k)
  end
end
