# frozen_string_literal: true

def serialize_opening_hours_description(description)
  I18n.with_locale(description.first_available_locale) do
    schedule_hash = description&.validity_schedule&.first&.schedule_object&.to_hash || {}

    {
      '@type' => 'OpeningHoursSpecification',
      'validFrom' => schedule_hash.dig(:start_time, :time)&.in_time_zone&.to_s(:only_date),
      'validThrough' => schedule_hash&.dig(:rrules, 0, :until)&.in_time_zone&.to_s(:only_date) || schedule_hash&.dig(:end_time, :time)&.in_time_zone&.to_s(:only_date),
      'description' => description&.description,
      'contentType' => 'Öffnungszeit',
      '@context' => 'http://schema.org'
    }.compact
  end
end

if value.present?
  key_name = attribute_key(key, definition)

  json.set! key_name do
    json.array!(value.map do |description|
      serialize_opening_hours_description(description)
    end)
  end
end
