# frozen_string_literal: true

classification_aliases = content.send(key).includes(:classification_aliases).map(&:classification_aliases).flatten.uniq

key_new = definition.dig('api', 'name') || key.camelize(:lower)
if classification_aliases.present?
  json.set! key_new, (classification_aliases.map do |classification_alias|
    case classification_alias.internal_name
    when 'Montag'
      'https://schema.org/Monday'
    when 'Dienstag'
      'https://schema.org/Tuesday'
    when 'Mittwoch'
      'https://schema.org/Wednesday'
    when 'Donnerstag'
      'https://schema.org/Thursday'
    when 'Freitag'
      'https://schema.org/Friday'
    when 'Samstag'
      'https://schema.org/Saturday'
    when 'Sonntag'
      'https://schema.org/Sunday'
    when 'Feiertag'
      'https://schema.org/PublicHolidays'
    else
      classification_alias.name
    end
  end)
end
