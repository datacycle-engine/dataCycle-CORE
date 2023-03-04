# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Export::Onlim::TransformationFunctions do
  subject do
    DataCycleCore::Export::Onlim::TransformationFunctions
  end

  describe 'transform_schedule' do
    let(:event) do
      {
        '@graph' => [{
          'eventSchedule' => [{
            '@id' => '13454614-f317-41b8-9a03-4d4d7a08b8b5',
            '@type' => 'Schedule',
            '@context' => 'https://schema.org/',
            'inLanguage' => 'de',
            'startDate' => '2022-10-14',
            'endDate' => '2022-10-14',
            'startTime' => '20:00',
            'endTime' => '22:00',
            'duration' => 'PT2H',
            'repeatFrequency' => 'P1W',
            'byDay' => [
              'https://schema.org/Friday'
            ],
            'scheduleTimezone' => 'Europe/Vienna'
          }]
        }]
      }
    end

    let(:correct_schedule) do
      {
        '@id' => '13454614-f317-41b8-9a03-4d4d7a08b8b5',
        '@type' => 'Schedule',
        '@context' => 'https://schema.org/',
        'inLanguage' => 'de',
        'startDate' => '2022-10-14',
        'endDate' => '2022-10-14',
        'startTime' => '20:00:00',
        'endTime' => '22:00:00',
        'duration' => {
          '@id' => '13454614-f317-41b8-9a03-f513b91c07f1', # generate_uuid('13454614-f317-41b8-9a03-4d4d7a08b8b5', 'duration')
          '@type' => 'Duration',
          'name' => 'PT2H'
        },
        'repeatFrequency' => 'P1W',
        'byDay' => [
          'https://schema.org/Friday'
        ],
        'scheduleTimezone' => 'Europe/Vienna'
      }
    end

    it 'transforms event_schedule to correct_schedule' do
      hash = subject.transform_schedule(event)
      schedule = hash.dig('@graph', 0, 'eventSchedule', 0)
      assert_equal(correct_schedule, schedule)
    end
  end

  describe 'transform_opening_hours_specifications' do
    let(:poi) do
      {
        '@graph' => [{
          'openingHoursSpecification' => [
            {
              '@id' => '8e4f1aa1-0f58-45b5-aad9-5be21c8b8584',
              '@type' => 'OpeningHoursSpecification',
              'validFrom' => '2023-03-03',
              'validThrough' => '2024-03-03',
              'opens' => '10:00',
              'closes' => '12:00',
              'dayOfWeek' => ['https://schema.org/Friday']
            }
          ]
        }]
      }
    end

    let(:correct_opening_hours_specifications) do
      {
        '@id' => '8e4f1aa1-0f58-45b5-aad9-5be21c8b8584',
        '@type' => 'OpeningHoursSpecification',
        'validFrom' => '2023-03-03',
        'validThrough' => '2024-03-03',
        'opens' => '10:00:00',
        'closes' => '12:00:00',
        'dayOfWeek' => ['https://schema.org/Friday']
      }
    end

    it 'transforms event_schedule to correct_schedule' do
      hash = subject.transform_opening_hours_specifications(poi)
      ohs = hash.dig('@graph', 0, 'openingHoursSpecification', 0)
      assert_equal(correct_opening_hours_specifications, ohs)
    end
  end
end
