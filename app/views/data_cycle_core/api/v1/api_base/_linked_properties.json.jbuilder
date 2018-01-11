default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes + ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})

(content.linked_property_names - options[:hidden_attributes]).each do |property|
  data = content.send(property)

  if data.size > 0
    json.set! property.pluralize.camelize(:lower) do
      json.array!(data) do |item|
        json.content_partial! 'details', content: item
      end
    end
  end
end
