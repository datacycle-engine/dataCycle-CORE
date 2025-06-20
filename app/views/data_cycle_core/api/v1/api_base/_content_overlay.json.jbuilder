# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.set! 'startDate', content.start_date if content.try(:start_date).present?
json.set! 'endDate', content.end_date if content.try(:end_date).present?

json.partial!('untranslated_properties', content:, locale: content.translations&.first&.locale || I18n.locale, options:)

if content.translations.one? { |t| !t.id.nil? }
  json.set! 'inLanguage', content.translations.first.locale
  json.partial! 'translated_properties', content:, locale: content.translations.first.locale, options:
else
  json.set! 'translations' do
    content.translations.each do |translation|
      json.set! translation.locale do
        json.partial! 'translated_properties', content:, locale: translation.locale, options:
      end
    end
  end
end

json.partial!('linked_properties', content:, options:)

json.partial!('embedded_properties', content:, options:)

json.partial! 'asset_properties', content:, options:
