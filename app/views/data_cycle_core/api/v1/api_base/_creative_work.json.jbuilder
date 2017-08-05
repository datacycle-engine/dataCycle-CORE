json.partial! 'preface', object: object, nested: defined?(nested) ? nested : false

linkedObjectDefinitions = object.metadata['validation']['properties']
  .select { |k, v| v['type'].starts_with?('embedded') }
  .reject { |k, v| DataCycleCore.special_data_attributes.include?(k) }

special_attributes = DataCycleCore.special_data_attributes + linkedObjectDefinitions.keys + ['validation']

object.metadata.reject { |k, v| v.blank? || special_attributes.include?(k) || k.ends_with?('hasPart') }.each do |key, value|
  json.set! key, value
end

if object.translations.count > 1 
  json.set! 'translations' do
    object.translations.each.each do |translation|
      json.set! translation.locale do
        Array(translation.content).reject { |k, v| v.blank? || special_attributes.include?(k) || k.ends_with?('hasPart') }.each do |key, value|
          json.set! key, value
        end
        Array(translation.properties).reject { |k, v| v.blank? || special_attributes.include?(k) || k.ends_with?('hasPart') }.each do |key, value|
          json.set! key, value
        end
      end
    end
  end
else
  json.set! 'inLanguage', object.translations.first.locale
  Array(object.translations.first.content).reject { |k, v| v.blank? || special_attributes.include?(k) || k.ends_with?('hasPart') }.each do |key, value|
    json.set! key, value
  end
  Array(object.translations.first.properties).reject { |k, v| v.blank? || special_attributes.include?(k) || k.ends_with?('hasPart') }.each do |key, value|
    json.set! key, value
  end  
end

linkedObjectDefinitions.each do |k, v|
  json.partial! v['type'].underscore, name: k, definition: v, data: object.send(v['storage_location'])[k]
end

if object.metadata.select { |k, v| k.ends_with?('hasPart') }.map { |k, v| v }.flatten.count > 0
  json.hasPart(object.metadata.select { |k, v| k.ends_with?('hasPart') }.map { |k, v| v }.flatten) do |part_id|
    json.partial! 'creative_work', object: DataCycleCore::CreativeWork.find(part_id), nested: true
  end
end

json.set! 'classifications' do
  json.array! object.classifications, partial: 'classification', as: :classification
end

