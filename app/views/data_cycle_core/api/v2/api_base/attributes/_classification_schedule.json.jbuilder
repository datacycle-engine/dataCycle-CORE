# frozen_string_literal: true

months = content
  .send(key)
  &.includes(:classification_aliases)
  &.map(&:classification_aliases)
  &.flatten&.uniq
  &.map(&:internal_name)
  &.map do |name|
    case name
    when 'Januar'
      1
    when 'Februar'
      2
    when 'März'
      3
    when 'April'
      4
    when 'Mai'
      5
    when 'Juni'
      6
    when 'Juli'
      7
    when 'August'
      8
    when 'September'
      9
    when 'Oktober'
      10
    when 'November'
      11
    when 'Dezember'
      12
    else
      name
    end
  end

data =
  {
    'schedule':
    [
      {
        '@context': 'http://schema.org',
        '@type': [
          'Intangible',
          'Schedule'
        ],
        'contentType': 'Schedule',
        'byMonth': months.sort
      }
    ]
  }

json.merge! data
