type = object.metadata['validation']['name']

begin
  json.partial! "#{object.class.class_name.underscore}_#{type.underscore}", object: object, nested: defined?(nested) ? nested : false
rescue ActionView::MissingTemplate => e
  logger.info "Using standard template for #{object.class.to_s} - #{type}"

  json.partial! 'preface', object: object

  special_attributes = DataCycleCore.special_data_attributes + ['validation']

  special_attributes = DataCycleCore.special_data_attributes + [
    'id', 'creator',
    'seen_at', 'created_at', 'updated_at',
    'validation', 'metadata', 'content', 'properties', 'template'
  ]

  if object.metadata['creator']
    user = DataCycleCore::User.find(object.metadata['creator'])
    json.set! 'creator', "#{user.name} <#{user.email}>"
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
        translation.attributes.reject { |k, v| v.nil? || (special_attributes + ['person_id', 'locale']).include?(k) }.each do |key, value|
          json.set! key, value
        end

        Array(translation.content).reject { |k, v| v.nil? || (special_attributes + ['person_id', 'locale']).include?(k) }.each do |key, value|
          json.set! key, value
        end

        Array(translation.properties).reject { |k, v| v.nil? || (special_attributes + ['person_id', 'locale']).include?(k) }.each do |key, value|
          json.set! key, value
        end
      end
    end
  end
end
