# frozen_string_literal: true

def serialize_opening_hours_description_v2(description)
  I18n.with_locale(description.first_available_locale) do
    schedule_hash = description&.validity_schedule&.first&.schedule_object&.to_hash || {}
    description_values = description&.property_definitions&.select { |k, v| attribute_key(k, v) == 'description' }&.sort_by { |_k, v| v['sorting'] }&.map { |k, _v| description.try(k) }

    {
      '@type' => 'OpeningHoursSpecification',
      'validFrom' => schedule_hash.dig(:start_time, :time)&.in_time_zone&.to_s(:only_date),
      'validThrough' => (
        schedule_hash&.dig(:rrules, 0, :until) ||
        (
          schedule_hash&.dig(:end_time, :time)&.then { |t| t - 1.second } if schedule_hash.dig(:rrules, 0, :rule_type).blank? || schedule_hash.dig(:rrules, 0, :rule_type) == 'IceCube::SingleOccurrenceRule'
        )
      )&.in_time_zone&.to_s(:only_date),
      'description' => description_values&.compact_blank&.first,
      'contentType' => 'Öffnungszeit',
      '@context' => 'http://schema.org'
    }.compact
  end
end

if value.present?
  key_name = attribute_key(key, definition)

  json.set! key_name do
    json.array!(value.map do |description|
      serialize_opening_hours_description_v2(description)
    end)
  end
end
