# frozen_string_literal: true

if content.present?
  key_name = attribute_key(key, definition)

  json.set! key_name do
    json.array!(content.send(key + '_overlay')&.map do |schedule|
      schedule&.to_opening_hours_specification_schema_org_api_v3&.compact
    end)
  end
end
