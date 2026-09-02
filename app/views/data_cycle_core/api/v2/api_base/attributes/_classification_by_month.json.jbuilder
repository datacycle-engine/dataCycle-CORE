# frozen_string_literal: true

classification_aliases = content.send(key)&.includes(:classification_aliases)&.map(&:classification_aliases)&.flatten&.uniq

key_new = definition.dig('api', 'name') || key.camelize(:lower)

if classification_aliases.present?
  month_numbers = {
    'Januar' => 1,
    'Februar' => 2,
    'März' => 3,
    'April' => 4,
    'Mai' => 5,
    'Juni' => 6,
    'Juli' => 7,
    'August' => 8,
    'September' => 9,
    'Oktober' => 10,
    'November' => 11,
    'Dezember' => 12
  }

  mapped = classification_aliases.map { |classification_alias| month_numbers[classification_alias.internal_name] || classification_alias.name }
  months, other = mapped.partition { |month| month.is_a?(Integer) }

  json.set! key_new, months.sort + other.sort
end
