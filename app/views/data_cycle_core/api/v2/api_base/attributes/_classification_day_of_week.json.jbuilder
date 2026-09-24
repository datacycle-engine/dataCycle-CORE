# frozen_string_literal: true

concepts = content.send(key)

key_new = definition.dig('api', 'name') || key.camelize(:lower)
if concepts.present?
  day_of_week_uris = {
    'Montag' => 'https://schema.org/Monday',
    'Dienstag' => 'https://schema.org/Tuesday',
    'Mittwoch' => 'https://schema.org/Wednesday',
    'Donnerstag' => 'https://schema.org/Thursday',
    'Freitag' => 'https://schema.org/Friday',
    'Samstag' => 'https://schema.org/Saturday',
    'Sonntag' => 'https://schema.org/Sunday',
    'Feiertag' => 'https://schema.org/PublicHolidays'
  }

  days_of_week = concepts.map { |concept| day_of_week_uris[concept.internal_name] || concept.name }

  json.set! key_new, days_of_week
end
