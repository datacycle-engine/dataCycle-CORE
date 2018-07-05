# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key'] + DataCycleCore::Feature::OverlayAttributeService.call(content)
}
options = default_options.merge(defined?(options) ? options || {} : {})

json.content_partial! 'header', content: content, options: options

# json.partial! 'container_parent_properties', content: content, options: options if DataCycleCore::Feature::Container.enabled? && content.try(:parent).present?

if content.translations.size > 1 && params.dig(:include) == 'translations'
  json.set! 'inLanguage', content.translations.map(&:locale)
else
  json.set! 'inLanguage', content.translations.first.locale
end

# json.partial! 'container_children_properties', content: content, options: options if DataCycleCore::Feature::Container.enabled? && content.content_type?('container')

json.content_partial! 'properties', content: content, options: options

# json.partial! 'overlay_properties', content: content, options: options
