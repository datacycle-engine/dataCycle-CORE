json.partial! 'header', object: object

object = DataCycleCore::ContentDecorator.new(object)

special_attributes = DataCycleCore.special_data_attributes +  DataCycleCore::ContentDecorator.special_property_names

((object.untranslatable_property_names & object.plain_property_names) - special_attributes).each do |key|
  json.set! key, object.property_value(key) unless object.property_value(key).blank?
end

if object.translations == 1 
  translation = object.translations.first

  json.set! 'inLanguage', translation.locale

  (object.translatable_property_names - special_attributes).each do |key|
    json.set! key, object.property_value(key) unless object.property_value(key).blank?
  end
else
  json.set! 'translations' do
    object.translations.each do |translation|
      json.set! translation.locale do
        (object.translatable_property_names - special_attributes).each do |key|
          json.set! key, object.property_value(key) unless object.property_value(key).blank?
        end
      end
    end
  end
end

object.linked_object_definitions.each do |k, v|
  json.partial! v['type'].underscore, name: k, definition: v, data: object.linked_object_data(k)
end
