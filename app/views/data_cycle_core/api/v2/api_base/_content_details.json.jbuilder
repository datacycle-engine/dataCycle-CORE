# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore::Feature::OverlayAttributeService.call(content),
  combined_attributes: content.combined_property_names
}
options = default_options.merge(defined?(options) ? options || {} : {})

json.content_partial! 'header', content: content, options: options

json.partial! 'container_parent_properties', content: content, options: options if DataCycleCore::Feature::Container.enabled? && content.try(:parent).present?

if content.translations.size > 1 && @include_parameters.include?('translations')
  json.set! 'inLanguage', content.translated_locales
else
  json.set! 'inLanguage', content.translated_locales.include?(@language.to_sym) ? @language : content.first_available_locale
end

json.partial! 'container_children_properties', content: content, options: options if DataCycleCore::Feature::Container.enabled? && content.content_type?('container')

json.content_partial! 'properties', content: content, options: options

json.partial! 'overlay_properties', content: content, options: options

json.partial! 'combined_properties', content:, options:
