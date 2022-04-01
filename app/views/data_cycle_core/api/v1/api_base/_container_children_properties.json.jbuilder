# frozen_string_literal: true

related_objects = DataCycleCore::CreativeWork
  .where(is_part_of: content.id)
  .includes({ classifications: { classification_aliases: { classification_tree: [:classification_tree_label] } }, translations: [] })

json.hasPart(related_objects) do |part|
  json.content_partial! 'header', content: part, options: { parent: false }

  if part.translations.reject { |t| t.id.nil? }.size == 1
    json.set! 'inLanguage', part.translations.first.locale
    json.partial! 'translated_properties', content: part, locale: part.translations.first.locale, options: options
  else
    json.set! 'translations' do
      part.translations.each do |translation|
        json.set! translation.locale do
          json.partial! 'translated_properties', content: part, locale: translation.locale, options: options
        end
      end
    end
  end
end
