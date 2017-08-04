json.partial! 'preface', object: object, nested: defined?(nested) ? nested : false

special_attributes = DataCycleCore.special_data_attributes + ['validation']

object.metadata.reject { |k, v| v.blank? || special_attributes.include?(k) || k.ends_with?('hasPart') }.each do |key, value|
  json.set! key, value
end

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

if object.metadata.select { |k, v| k.ends_with?('hasPart') }.map { |k, v| v }.flatten.count > 0
  json.hasPart(object.metadata.select { |k, v| k.ends_with?('hasPart') }.map { |k, v| v }.flatten) do |part_id|
    json.partial! 'creative_work', object: DataCycleCore::CreativeWork.find(part_id), nested: true
  end
end

json.set! 'classifications' do
  json.array! object.classifications, partial: 'classification', as: :classification
end

