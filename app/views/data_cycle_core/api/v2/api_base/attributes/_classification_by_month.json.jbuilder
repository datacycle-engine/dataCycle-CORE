# frozen_string_literal: true

concepts = content.send(key)

key_new = definition.dig('api', 'name') || key.camelize(:lower)

if concepts.present?
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

  mapped = concepts.map { |concept| month_numbers[concept.internal_name] || concept.name }
  months, other = mapped.partition { |month| month.is_a?(Integer) }

  json.set! key_new, months.sort + other.sort
end
