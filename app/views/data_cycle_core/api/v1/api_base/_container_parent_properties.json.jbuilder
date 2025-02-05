# frozen_string_literal: true

if content&.parent&.content_type?('container')
  json.set! 'isPartOf' do
    json.content_partial!('header', content: content.parent, options:)

    if content.parent.translations.count { |t| !t.id.nil? } == 1
      json.set! 'inLanguage', content.parent.translations.first.locale
      json.partial! 'translated_properties', content: content.parent, locale: content.parent.translations.first.locale, options:
    else
      json.set! 'translations' do
        content.parent.translations.each do |translation|
          json.set! translation.locale do
            json.partial! 'translated_properties', content: content.parent, locale: translation.locale, options:
          end
        end
      end
    end
  end
end
