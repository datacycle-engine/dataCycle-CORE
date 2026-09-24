# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    module Schemas
      module SharedComponents
        # Schedule / OpeningHoursSpecification building blocks. Extended into
        # SharedComponents so its methods are available as
        # SharedComponents.* module methods (mirrors Localizable).
        module Temporal
          # schema.org Schedule per Schedule#to_schedule_schema_org.
          def schedule
            {
              'type' => 'object',
              'title' => 'Schedule',
              'properties' => {
                '@context' => { 'type' => 'string', 'format' => 'uri' },
                '@id' => id_property,
                '@type' => { 'type' => 'string', 'const' => 'Schedule' },
                'inLanguage' => { 'type' => 'string' },
                'startDate' => { 'type' => 'string', 'format' => 'date' },
                'endDate' => { 'type' => 'string', 'format' => 'date' },
                'startTime' => { 'type' => 'string' },
                'endTime' => { 'type' => 'string' },
                'duration' => { 'type' => 'string', 'description' => t('schemas.schedule_duration') },
                'repeatCount' => { 'type' => 'integer' },
                'exceptDate' => { 'type' => 'array', 'items' => { 'type' => 'string', 'format' => 'date-time' } },
                'dc:additionalDate' => { 'type' => 'array', 'items' => { 'type' => 'string', 'format' => 'date-time' } },
                'repeatFrequency' => { 'type' => 'string', 'description' => t('schemas.schedule_repeat_frequency') },
                'byDay' => {
                  'oneOf' => [
                    { 'type' => 'string' },
                    { 'type' => 'array', 'items' => { 'type' => 'string' } }
                  ]
                },
                'byMonth' => { 'type' => 'array', 'items' => { 'type' => 'integer' } },
                'byMonthDay' => { 'type' => 'array', 'items' => { 'type' => 'integer' } },
                'byMonthWeek' => { 'type' => 'integer' },
                'scheduleTimezone' => { 'type' => 'string' }
              },
              'required' => ['@type']
            }
          end

          # schema.org OpeningHoursSpecification per the embedded partial.
          def opening_hours_specification
            {
              'type' => 'object',
              'title' => 'OpeningHoursSpecification',
              'properties' => {
                '@type' => { 'type' => 'string', 'const' => 'OpeningHoursSpecification' },
                'opens' => { 'type' => 'string' },
                'closes' => { 'type' => 'string' },
                'dayOfWeek' => {
                  'type' => 'array',
                  'items' => { '$ref' => '#/components/schemas/Concept' }
                },
                'validFrom' => { 'type' => 'string', 'format' => 'date-time' },
                'validThrough' => { 'type' => 'string', 'format' => 'date-time' },
                'dct:modified' => { 'type' => 'string', 'format' => 'date-time' }
              },
              'required' => ['@type']
            }
          end
        end
      end
    end
  end
end
