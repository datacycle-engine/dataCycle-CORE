# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key'] + DataCycleCore::Feature::OverlayAttributeService.call(content)
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.content_partial! 'header', content: content, options: options

options[:hidden_attributes] += ['latitude', 'longitude', 'elevation', 'location']

if content.translations.size == 1
  json.set! 'inLanguage', content.translations.first.locale
else
  json.set! 'availableLanguages', content.translations.map(&:locale)

  # activate for oew
  # json.set! 'translations' do
  #   content.translations.each do |translation|
  #     json.set! translation.locale do
  #       json.partial! 'translated_properties', content: content, locale: translation.locale, options: options
  #     end
  #   end
  # end
end

unless content.schema.nil?

  ordered_validation_properties(validation: content.schema, content_area: 'content').each do |key, prop|
    next if options[:hidden_attributes].include?(key)
    value = content.try(key.to_sym)
    value = value.presence&.page&.per(DataCycleCore.linked_objects_page_size) if value.is_a?(ActiveRecord::Relation)

    json.render_attribute! key: key, definition: prop, value: value, parameters: { options: options }, content: content
  end

end

if (content.latitude && content.longitude) || content.elevation
  json.set! 'geo' do
    json.partial! 'geo', geoData: content
  end
end
