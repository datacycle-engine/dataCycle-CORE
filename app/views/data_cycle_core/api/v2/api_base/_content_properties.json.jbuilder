# frozen_string_literal: true

unless content.schema.nil?

  ordered_validation_properties(validation: content.schema).each do |key, prop|
    next if options[:hidden_attributes].include?(key) || options[:combined_attributes].include?(key) || (@mode_parameters.include?('minimal') && !prop.dig('api', 'minimal'))
    value = content.try(key.to_sym)

    json.partial!(*(render_api_attribute key: key, definition: prop, value: value, parameters: { options: options }, content: content))
  end

end
