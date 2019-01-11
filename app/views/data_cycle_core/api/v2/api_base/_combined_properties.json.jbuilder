# frozen_string_literal: true

combined = {}
options.dig(:combined_attributes).each do |property|
  definition = content.properties_for(property)
  next if definition.blank?
  (combined[definition.dig('api', 'transformation', 'name')] ||= []) << [property, definition]
end

combined.each do |combined_key, combined_value|
  json.set! combined_key do
    json.array!(combined_value) do |key, definition|
      json.partial!(*(render_api_attribute key: key, definition: definition, value: content.try(key.to_sym), parameters: { options: options }, content: content))
    end
  end
end
