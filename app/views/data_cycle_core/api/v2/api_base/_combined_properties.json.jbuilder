# frozen_string_literal: true

def concat_string(key, value)
  return if value.blank?
  "<section data-attribute=\"#{key}\">#{value}</section>"
end

def concated_keys_translateable?(keys, content)
  keys.each do |key|
    return false unless content.translatable_property_names.include?(key)
  end
  true
end

combined = {}
options[:combined_attributes].each do |property|
  definition = content.properties_for(property)
  next if definition.blank?
  combined[definition.dig('api', 'transformation', 'name')] ||= {
    'transformation' => definition.dig('api', 'transformation'),
    'items' => []
  }
  combined[definition.dig('api', 'transformation', 'name')]['items'] << [property, definition]
end

combined.each do |combined_key, combined_value|
  if combined_value.dig('transformation', 'values') == 'concat'
    # only default values
    # values must either be stored in value or translated_value
    if content.translations.size > 1 && concated_keys_translateable?(combined_value['items'].map(&:first), content) && @include_parameters.include?('translations')
      concated_translated_value = {}
      combined_value['items'].each do |key, definition|
        content.translations.each do |translation|
          I18n.with_locale(translation.locale) do
            (concated_translated_value[translation.locale] ||= []) << concat_string(definition.dig('api', 'transformation', 'section_name') || key, content.send(key)).to_s
          end
        end
        json.set! combined_key, concated_translated_value
      end
    else
      concated_value = ''
      combined_value['items'].each do |key, definition|
        concated_value << concat_string(definition.dig('api', 'transformation', 'section_name') || key, content.try(key.to_sym)).to_s
      end
      json.set! combined_key, concated_value
    end
  else
    json.set! combined_key do
      json.array!(combined_value['items']) do |key, definition|
        partial_params = render_api_attribute key: key, definition: definition, value: content.try(key.to_sym), parameters: { options: options }, content: content
        json.partial!(*partial_params) unless partial_params.nil?
      end
    end
  end
end
