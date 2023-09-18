# frozen_string_literal: true

unless content.schema.nil?

  ordered_api_properties(validation: content.schema).each do |key, prop|
    next if options[:hidden_attributes].include?(key) || options[:combined_attributes].include?(key) || (@mode_parameters.include?('minimal') && !prop.dig('api', 'minimal'))
    next if content.schema&.dig('properties', key, 'link_direction') == 'inverse'
    value = content.try(key.to_sym)

    partial_params = render_api_attribute key: key, definition: prop, value: value, parameters: { options: options }, content: content
    json.partial!(*partial_params) unless partial_params.nil?
  end

end
