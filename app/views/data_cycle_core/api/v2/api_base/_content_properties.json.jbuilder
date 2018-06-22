# frozen_string_literal: true

unless content.schema.nil?

  ordered_validation_properties(validation: content.schema).each do |key, prop|
    next if options[:hidden_attributes].include?(key)
    value = content.try(key.to_sym)

    json.render_attribute! key: key, definition: prop, value: value, parameters: { options: options }, content: content
  end

end
