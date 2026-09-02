# frozen_string_literal: true

classification_aliases = content.send(key).includes(:classification_aliases).map(&:classification_aliases).flatten.uniq

key_new = definition.dig('api', 'name') || key.camelize(:lower)
if classification_aliases.present?
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

  days_of_week = classification_aliases.map { |classification_alias| day_of_week_uris[classification_alias.internal_name] || classification_alias.name }

  json.set! key_new, days_of_week
end
