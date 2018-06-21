# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key'] + DataCycleCore::Feature::OverlayAttributeService.call(content)
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.content_partial! 'header', content: content, options: options

# oew version
json.partial! 'container_parent_properties', content: content, options: options if DataCycleCore::Feature::Container.enabled? && content.try(:parent).present?

if content.translations.size == 1
  json.set! 'inLanguage', content.translations.first.locale
else
  json.set! 'availableLanguages', content.translations.map(&:locale)

  # activate for oew
  # test compatibility
  # json.set! 'translations' do
  #   content.translations.each do |translation|
  #     json.set! translation.locale do
  #       json.partial! 'translated_properties', content: content, locale: translation.locale, options: options
  #     end
  #   end
  # end
end

json.partial! 'container_children_properties', content: content, options: options if DataCycleCore::Feature::Container.enabled? && content.content_type?('container')

json.content_partial! 'properties', content: content, options: options

json.partial! 'overlay_properties', content: content, options: options
