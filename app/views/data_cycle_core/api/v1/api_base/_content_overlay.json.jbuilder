default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.set! 'startDate', content.start_date unless content.try(:start_date).blank?
json.set! 'endDate', content.end_date unless content.try(:end_date).blank?

json.partial! 'untranslated_properties', content: content, locale: content.translations.first.locale, options: options

if content.translations.reject { |t| t.id.nil? }.size == 1
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

json.partial! 'asset_properties', content: content, options: options