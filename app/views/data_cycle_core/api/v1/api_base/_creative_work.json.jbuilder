json.partial! 'preface', object: object

special_attributes = DataCycleCore.special_data_attributes + ['validation']

object.metadata.reject { |k, v| v.blank? || special_attributes.include?(k) }.each do |key, value|
  json.set! key, value
end

json.set! 'translations' do
  object.translations.each.each do |translation|
    json.set! translation.locale do
      Array(translation.content).reject { |k, v| v.blank? || special_attributes.include?(k) }.each do |key, value|
        json.set! key, value
      end
      Array(translation.properties).reject { |k, v| v.blank? || special_attributes.include?(k) }.each do |key, value|
        json.set! key, value
      end
    end
  end
end

json.set! 'classifications' do
  json.array! object.classifications, partial: 'classification', as: :classification
end
