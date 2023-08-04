# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

(content.linked_property_names - options[:hidden_attributes]).each do |property|
  next if content.schema&.dig('properties', property, 'link_direction') == 'inverse'

  data = content.send(property).includes(:translations, :classifications)

  next if data.empty?
  json.set! property.pluralize.camelize(:lower) do
    json.array!(data) do |item|
      @duplicate_linked_in_path ||= []

      if @duplicate_linked_in_path.include?(item.id)
        json.cache!(api_cache_key(item, I18n.locale, [], ['header_only']), expires_in: 24.hours + Random.rand(12.hours)) do
          json.content_partial! 'header', content: item, options:
        end
      else
        @duplicate_linked_in_path << item.id
        json.cache!(api_cache_key(item, I18n.locale, [], []), expires_in: 24.hours + Random.rand(12.hours)) do
          json.content_partial! 'details', content: item
        end
        @duplicate_linked_in_path.delete(item.id)
      end
    end
  end
end
