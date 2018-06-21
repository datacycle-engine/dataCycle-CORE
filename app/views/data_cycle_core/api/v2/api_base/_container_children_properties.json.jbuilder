# frozen_string_literal: true

related_objects = DataCycleCore::CreativeWork
  .where(is_part_of: content.id)
  .includes({ classifications: { classification_aliases: { classification_tree: [:classification_tree_label] } }, translations: [] })

json.hasPart(related_objects) do |part|
  json.content_partial! 'header', content: part, options: { parent: false }

  if part.translations.reject { |t| t.id.nil? }.size == 1
    json.set! 'inLanguage', part.translations.first.locale
    # json.partial! 'translated_properties', content: part, locale: part.translations.first.locale, options: options
  else
    json.set! 'availableLanguages', part.translations.map(&:locale)
    # json.set! 'translations' do
    #   part.translations.each do |translation|
    #     json.set! translation.locale do
    #       json.partial! 'translated_properties', content: part, locale: translation.locale, options: options
    #     end
    #   end
    # end
  end

  unless content.schema.nil?

    ordered_validation_properties(validation: content.schema).each do |key, prop|
      next if options[:hidden_attributes].include?(key)
      value = content.try(key.to_sym)
      value = value.presence&.page&.per(DataCycleCore.linked_objects_page_size) if value.is_a?(ActiveRecord::Relation)

      json.render_attribute! key: key, definition: prop, value: value, parameters: { options: options }, content: content
    end

  end
end
