default_options = {
  hidden_attributes: DataCycleCore.special_data_attributes +  ['external_source_id', 'external_key']
}

options = default_options.merge(defined?(options) ? options || {} : {})


(content.linked_property_names - options[:hidden_attributes]).each do |property|
  property_definition = content.property_definitions[property]

  data = content.send(property)

  if data.is_a?(Array)
    if !data.empty?    
      json.set! property.pluralize do
        json.array!(data) do |data_item|
          json.content_partial! 'details', content: data_item
        end
      end
    end
  elsif !data.nil?
    json.set! property do
      json.content_partial! 'details', content: data
    end
  end
end