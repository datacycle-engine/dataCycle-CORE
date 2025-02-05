# frozen_string_literal: true

if content.present?
  key_name = attribute_key(key, definition)
  value = content.send(:"#{key}_overlay")

  if value.present?
    json.set! key_name do
      json.array!(value.map do |schedule|
        schedule&.to_opening_hours_specification_schema_org_api_v3&.compact
      end)
    end
  end
end
