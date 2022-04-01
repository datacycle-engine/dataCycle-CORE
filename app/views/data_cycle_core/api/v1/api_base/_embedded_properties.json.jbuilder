# frozen_string_literal: true

default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})
(content.embedded_property_names - options[:hidden_attributes]).each do |property|
  data = nil
  I18n.with_locale(content.first_available_locale) do
    data = content.send(property).includes(:translations, :classifications)
  end
  next if data.empty?
  json.set! property.pluralize.camelize(:lower) do
    json.array!(data) do |item|
      json.cache!(api_cache_key(item, I18n.locale, [], []), expires_in: 24.hours + Random.rand(12.hours)) do
        json.content_partial! 'details', content: item
      end
    end
  end
end
