# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StoredFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'sort_by_in_occurrence_with_distance with format (lon,lat,start_date,end_date,sortAttr)' do
      order_string = '14,46,2025-05-01,2025-05-31,eventSchedule'
      expected = [['14', '46'], { 'in' => { 'min' => '2025-05-01', 'max' => '2025-05-31' }, 'relation' => 'eventSchedule' }]

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_in_occurrence_with_distance with format (start,end,sortAttr)' do
      order_string = 'start:2025-05-01,end:2025-05-31,attr:eventSchedule'
      expected = [[], { 'in' => { 'min' => '2025-05-01', 'max' => '2025-05-31' }, 'relation' => 'eventSchedule' }]
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_in_occurrence_with_distance with format (lon,lat,sortAttr)' do
      order_string = 'lon:14,lat:46,attr:eventSchedule'
      expected = [['14', '46'], { 'relation' => 'eventSchedule' }]
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_in_occurrence_with_distance with format (lon,lat)' do
      order_string = 'lon:14,lat:46'
      expected = [['14', '46']]
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_in_occurrence_with_distance with format (sortAttr)' do
      order_string = 'attr:eventSchedule'
      expected = [[], { 'relation' => 'eventSchedule' }]
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_in_occurrence_with_distance with format (start_date,end_date)' do
      order_string = 'start:2025-05-01,end:2025-05-31'
      expected = [[], { 'in' => { 'min' => '2025-05-01', 'max' => '2025-05-31' } }]
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_in_occurrence_with_distance with format (lon,start_date,sortAttr)' do
      order_string = 'lon:14,start:2025-05-01,attr:eventSchedule'
      expected = [['14', nil], { 'in' => { 'min' => '2025-05-01', 'max' => nil }, 'relation' => 'eventSchedule' }]
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_in_occurrence_with_distance with format (,lat,,end_date,sortAttr)' do
      order_string = 'lat:46,end:2025-05-01,attr:eventSchedule'
      expected = [[nil, '46'], { 'in' => { 'min' => nil, 'max' => '2025-05-01' }, 'relation' => 'eventSchedule' }]
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_in_occurrence_with_distance, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_by_proximity_value with format (start,end,sortAttr)' do
      order_string = '2025-05-01,2025-05-31,eventSchedule'
      expected = { 'min' => '2025-05-01', 'max' => '2025-05-31', 'relation' => 'eventSchedule' }
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_proximity_value, {}, order_string)&.dig('v', 'v')

      assert_equal(expected, actual)
    end

    test 'sort_by_proximity_value with format (start,end)' do
      order_string = 'start:2025-05-01,end:2025-05-31'
      expected = { 'min' => '2025-05-01', 'max' => '2025-05-31' }
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_proximity_value, {}, order_string)&.dig('v', 'v')

      assert_equal(expected, actual)
    end

    test 'sort_by_proximity_value with format (sortAttr)' do
      order_string = 'attr:eventSchedule'
      expected = { 'relation' => 'eventSchedule' }
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_proximity_value, {}, order_string)&.dig('v', 'v')

      assert_equal(expected, actual)
    end

    test 'sort_by_proximity_value with format (start,sortAttr)' do
      order_string = 'start:2025-05-01,attr:eventSchedule'
      expected = { 'min' => '2025-05-01', 'relation' => 'eventSchedule' }
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_by_proximity_value, {}, order_string)&.dig('v', 'v')

      assert_equal(expected, actual)
    end

    test 'sort_proximity_in_time with relative in min' do
      value = {
        'q' => 'relative',
        'in' => { 'min' => { 'n' => 0, 'unit' => 'day', 'mode' => 'p' } }
      }

      search = DataCycleCore::Filter::Search.new
      sql = search.sort_proximity_in_time('', value).to_sql

      assert_includes(sql, "ORDER BY ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'end_date' AS timestamp without time zone) - relative_date('{\"n\":0,\"unit\":\"day\",\"mode\":\"p\"}'::jsonb))), ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone) - relative_date('{\"n\":0,\"unit\":\"day\",\"mode\":\"p\"}'::jsonb))), CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone), \"things\".\"id\" DESC")

      value = {
        'q' => 'relative',
        'in' => { 'min' => { 'n' => 0, 'unit' => 'month', 'mode' => 'p' } }
      }

      search = DataCycleCore::Filter::Search.new
      sql = search.sort_proximity_in_time('', value).to_sql

      assert_includes(sql, "ORDER BY ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'end_date' AS timestamp without time zone) - relative_date('{\"n\":0,\"unit\":\"month\",\"mode\":\"p\"}'::jsonb))), ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone) - relative_date('{\"n\":0,\"unit\":\"month\",\"mode\":\"p\"}'::jsonb))), CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone), \"things\".\"id\" DESC")

      value = {
        'q' => 'relative',
        'in' => { 'min' => { 'n' => 0, 'unit' => 'year', 'mode' => 'p' } }
      }

      search = DataCycleCore::Filter::Search.new
      sql = search.sort_proximity_in_time('', value).to_sql

      assert_includes(sql, "ORDER BY ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'end_date' AS timestamp without time zone) - relative_date('{\"n\":0,\"unit\":\"year\",\"mode\":\"p\"}'::jsonb))), ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone) - relative_date('{\"n\":0,\"unit\":\"year\",\"mode\":\"p\"}'::jsonb))), CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone), \"things\".\"id\" DESC")
    end

    test 'sort_proximity_in_time with relative v from' do
      value = {
        'q' => 'relative',
        'v' => { 'from' => { 'n' => 2, 'unit' => 'day', 'mode' => 'p' } }
      }

      search = DataCycleCore::Filter::Search.new
      sql = search.sort_proximity_in_time('', value).to_sql

      assert_includes(sql, "ORDER BY ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'end_date' AS timestamp without time zone) - relative_date('{\"n\":2,\"unit\":\"day\",\"mode\":\"p\"}'::jsonb))), ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone) - relative_date('{\"n\":2,\"unit\":\"day\",\"mode\":\"p\"}'::jsonb))), CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone), \"things\".\"id\" DESC")
      value = {
        'q' => 'relative',
        'v' => { 'from' => { 'n' => 2, 'unit' => 'month', 'mode' => 'p' } }
      }

      search = DataCycleCore::Filter::Search.new
      sql = search.sort_proximity_in_time('', value).to_sql

      assert_includes(sql, "ORDER BY ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'end_date' AS timestamp without time zone) - relative_date('{\"n\":2,\"unit\":\"month\",\"mode\":\"p\"}'::jsonb))), ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone) - relative_date('{\"n\":2,\"unit\":\"month\",\"mode\":\"p\"}'::jsonb))), CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone), \"things\".\"id\" DESC")
      value = {
        'q' => 'relative',
        'v' => { 'from' => { 'n' => 2, 'unit' => 'year', 'mode' => 'p' } }
      }

      search = DataCycleCore::Filter::Search.new
      sql = search.sort_proximity_in_time('', value).to_sql

      assert_includes(sql, "ORDER BY ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'end_date' AS timestamp without time zone) - relative_date('{\"n\":2,\"unit\":\"year\",\"mode\":\"p\"}'::jsonb))), ABS(DATE_PART('day', CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone) - relative_date('{\"n\":2,\"unit\":\"year\",\"mode\":\"p\"}'::jsonb))), CAST(\"things\".\"metadata\" ->> 'start_date' AS timestamp without time zone), \"things\".\"id\" DESC")
    end

    test 'date_from_filter_object raises for inverted relative bounds' do
      value = {
        'min' => { 'n' => 10, 'unit' => 'day', 'mode' => 'p' },
        'max' => { 'n' => 1, 'unit' => 'day', 'mode' => 'p' }
      }

      assert_raises(DataCycleCore::Error::Filter::DateFilterRangeError) do
        DataCycleCore::Filter::Common::Date.date_from_filter_object(value)
      end

      value = {
        'min' => '2026-05-10',
        'max' => '2026-05-01'
      }

      assert_raises(DataCycleCore::Error::Filter::DateFilterRangeError) do
        DataCycleCore::Filter::Common::Date.date_from_filter_object(value)
      end
    end

    test 'sort_proximity_geographic_with_value with format (lon,lat)' do
      order_string = '14,46'
      expected = ['14', '46']
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_proximity_geographic_with_value, {}, order_string)&.dig('v')

      assert_equal(expected, actual)
    end

    test 'sort_proximity_geographic_with_value with format (lon)' do
      order_string = 'lon:14'
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_proximity_geographic_with_value, {}, order_string)&.dig('v')

      assert_nil(actual)
    end

    test 'sort_proximity_geographic_with_value with format (lat)' do
      order_string = 'lat:46'
      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:sort_proximity_geographic_with_value, {}, order_string)&.dig('v')

      assert_nil(actual)
    end

    test 'merge_api_filter_params for missing lon/lat' do
      sort_string = [[nil, nil], { 'in' => { 'min' => '2025-04-01', 'max' => '2025-05-01' }, 'relation' => 'eventSchedule' }]
      filter_string = [['14', '46'], { 'in' => { 'min' => '2025-04-03', 'max' => '2025-05-03' }, 'relation' => 'openingHoursSpecification' }]

      expected = [['14', '46'], { 'from' => '2025-04-03', 'until' => '2025-05-01', 'relation' => 'eventSchedule' }]
      expected[1]['from'], expected[1]['until'] = DataCycleCore::Filter::Common::Date.date_from_filter_object(expected[1])

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_by_in_occurrence_with_distance')

      assert_equal(expected, actual)
    end

    test 'merge_api_filter_params for missing start_date/end_date' do
      sort_string = [['14', '46'], { 'relation' => 'eventSchedule' }]
      filter_string = [['12', '47'], { 'in' => { 'min' => '2025-04-03', 'max' => '2025-05-03' }, 'relation' => 'openingHoursSpecification' }]

      expected = [['14', '46'], { 'relation' => 'eventSchedule', 'from' => '2025-04-03', 'until' => '2025-05-03' }]
      expected[1]['from'], expected[1]['until'] = DataCycleCore::Filter::Common::Date.date_from_filter_object(expected[1])

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_by_in_occurrence_with_distance')

      assert_equal(expected, actual)
    end

    test 'merge_api_filter_params for missing relation' do
      sort_string = [['14', '46'], { 'in' => { 'min' => '2025-04-01', 'max' => '2025-05-01' } }]
      filter_string = [['12', '47'], { 'in' => { 'min' => '2025-04-03', 'max' => '2025-05-03' }, 'relation' => 'openingHoursSpecification' }]

      expected = [['14', '46'], { 'from' => '2025-04-03', 'until' => '2025-05-01', 'relation' => 'openingHoursSpecification' }]
      expected[1]['from'], expected[1]['until'] = DataCycleCore::Filter::Common::Date.date_from_filter_object(expected[1])

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_by_in_occurrence_with_distance')

      assert_equal(expected, actual)
    end

    test 'merge_api_filter_params for proximity.occurrence merge relation' do
      sort_string = { 'q' => nil, 'v' => { 'min' => '2025-04-01', 'max' => '2025-05-01' } }
      filter_string = { 'in' => { 'min' => '2025-04-03', 'max' => '2025-05-03' }, 'relation' => 'openingHoursSpecification' }

      expected = { 'q' => nil, 'v' => { 'from' => '2025-04-03', 'until' => '2025-05-01', 'relation' => 'openingHoursSpecification' } }
      expected['v']['from'], expected['v']['until'] = DataCycleCore::Filter::Common::Date.date_from_filter_object(expected['v'])

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_by_proximity_value')

      assert_equal(expected, actual)
    end

    test 'merge_api_filter_params for proximity.occurrence merge date' do
      sort_string = { 'q' => nil, 'v' => { 'relation' => 'openingHoursSpecification' } }
      filter_string = { 'in' => { 'min' => '2025-04-03', 'max' => '2025-05-03' }, 'relation' => 'openingHoursSpecification' }

      expected = { 'q' => nil, 'v' => { 'from' => '2025-04-03', 'until' => '2025-05-03', 'relation' => 'openingHoursSpecification' } }
      expected['v']['from'], expected['v']['until'] = DataCycleCore::Filter::Common::Date.date_from_filter_object(expected['v'])

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_by_proximity_value')

      assert_equal(expected, actual)
    end

    test 'merge_api_filter_params for proximity.occurrence merge all' do
      sort_string = { 'q' => nil, 'v' => nil }
      filter_string = { 'in' => { 'min' => '2025-04-03', 'max' => '2025-05-03' }, 'relation' => 'openingHoursSpecification' }

      expected = { 'q' => nil, 'v' => { 'in' => { 'min' => '2025-04-03', 'max' => '2025-05-03' }, 'relation' => 'openingHoursSpecification' } }

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_by_proximity_value')

      assert_equal(expected, actual)
    end

    test 'merge_api_filter_params for proximity.geographic do nothing' do
      sort_string = [['14']]
      filter_string = [['12', '47']]

      expected = [['14']]

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_proximity_geographic_value')

      assert_equal(expected, actual)
    end

    test 'merge_api_filter_params for proximity.geographic missing both coordinates do nothing' do
      sort_string = []
      filter_string = [['12', '47']]

      expected = []

      stored_filter = DataCycleCore::StoredFilter.new
      actual = stored_filter.send(:merge_api_filter_params, sort_string, filter_string, 'sort_proximity_geographic_value')

      assert_equal(expected, actual)
    end
  end
end
