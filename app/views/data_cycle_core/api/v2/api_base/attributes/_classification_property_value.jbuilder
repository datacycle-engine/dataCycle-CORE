# frozen_string_literal: true

unless @mode_parameters.include?('compact')
  classification_aliases = content.send(key).includes(:classification_aliases).map(&:classification_aliases).flatten.uniq
  if classification_aliases.present? && definition.dig('api', 'disabled').blank?
    key_new = definition.dig('api', 'name') || key.camelize(:lower)

    json.partial! 'data_cycle_core/api/v2/api_base/headers/property_value', key: key_new, definition: definition
    json.set! 'valueReference' do
      json.array!(classification_aliases) do |classification_alias|
        json.set! 'identifier', classification_alias.id
        json.set! '@type', 'Enumeration'
        json.set! 'name', classification_alias.name
      end
    end
  end
end
