# frozen_string_literal: true

if content&.parent && content&.parent&.content_type?('container')
  json.set! 'isPartOf' do
    json.content_partial! 'header', content: content.parent, options: options

    if content.parent.translations.size == 1
      json.set! 'inLanguage', content.parent.translations.first.locale
    else
      json.set! 'availableLanguages', content.parent.translations.map(&:locale)

      # json.set! 'translations' do
      #   content.parent.translations.each do |translation|
      #     json.set! translation.locale do
      #       json.partial! 'translated_properties', content: content.parent, locale: translation.locale, options: options
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
end
