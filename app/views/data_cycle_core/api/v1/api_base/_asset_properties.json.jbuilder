default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

(content.asset_property_names - options[:hidden_attributes]).each do |property|
  data = content.send(property)

  next unless data.size.positive?
  json.set! property.pluralize.camelize(:lower) do
    json.array! data, partial: 'asset', as: :asset
  end
end
