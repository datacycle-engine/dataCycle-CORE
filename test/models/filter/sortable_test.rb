# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SortableTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def search
      DataCycleCore::Filter::Search.new(locale: ['de'])
    end

    test 'sanitized_order_string returns sanitized order fragment' do
      assert_equal('things.boost asc', search.sanitized_order_string('things.boost', 'ASC'))
      assert_equal('things.boost desc', search.sanitized_order_string('things.boost', 'desc'))
      assert_equal('things.boost desc NULLS LAST', search.sanitized_order_string('things.boost', 'DESC', true))
    end

    test 'sanitized_order_string raises for invalid ordering or blank order string' do
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sanitized_order_string('things.boost', 'sideways') }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sanitized_order_string('things.boost', nil) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sanitized_order_string('', 'asc') }
    end

    test 'sort_boost orders by things.boost in both directions' do
      assert_includes(search.sort_boost('ASC').to_sql, '"things"."boost" ASC')
      assert_includes(search.sort_boost('DESC').to_sql, '"things"."boost" DESC')
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_boost('invalid') }
    end

    test 'sort_advanced_attribute orders by advanced attribute from searches table' do
      sql = search.sort_advanced_attribute('ASC', 'start_date').to_sql

      assert_includes(sql, "LEFT OUTER JOIN searches ON searches.content_data_id = things.id AND searches.locale = 'de'")
      assert_includes(sql, "searches.advanced_attributes -> 'start_date' asc NULLS LAST")
      assert_includes(search.sort_advanced_attribute('DESC', 'start_date').to_sql, "searches.advanced_attributes -> 'start_date' desc NULLS LAST")
    end

    test 'sort_proximity_geographic returns self for missing coordinates' do
      base = search

      assert_same(base, base.sort_proximity_geographic('ASC', []))
      assert_same(base, base.sort_proximity_geographic('ASC', [nil, '47']))
      assert_same(base, base.sort_proximity_geographic('ASC', ['10', nil]))
    end

    test 'sort_proximity_geographic orders by distance to given point' do
      sql = search.sort_proximity_geographic('ASC', ['10', '47']).to_sql

      assert_includes(sql, 'LEFT OUTER JOIN geometries ON geometries.thing_id = things.id AND geometries.is_primary = true')
      assert_includes(sql, "geometries.geom_simple::geography <-> 'SRID=4326;POINT (10.0 47.0)'::geography asc NULLS LAST")
      assert_includes(search.sort_proximity_geographic('DESC', ['10', '47']).to_sql, 'desc NULLS LAST')
    end

    test 'sort_proximity_geographic_with delegates to sort_proximity_geographic' do
      sql = search.sort_proximity_geographic_with('ASC', ['10', '47']).to_sql

      assert_includes(sql, "geometries.geom_simple::geography <-> 'SRID=4326;POINT (10.0 47.0)'::geography asc NULLS LAST")
    end

    # DC-19: the ORDER BY geom literal interpolates the coordinates; non-numeric input must be
    # rejected (return self / unsorted) so it can never break out of the WKT literal.
    SQLI_COORD_PAYLOAD = "0 0)'::geography ASC, (SELECT 1 FROM pg_sleep(3)) ASC, 'SRID=4326;POINT (0"

    test 'sort_proximity_geographic returns self for non-numeric (SQL injection) coordinates' do
      base = search

      assert_same(base, base.sort_proximity_geographic('ASC', [SQLI_COORD_PAYLOAD, '0']))
      assert_same(base, base.sort_proximity_geographic('ASC', ['0', SQLI_COORD_PAYLOAD]))
      assert_same(base, base.sort_proximity_geographic_with('ASC', [SQLI_COORD_PAYLOAD, '0']))
      assert_same(base, base.sort_proximity_occurrence_with_distance('ASC', [[SQLI_COORD_PAYLOAD, '0']]))
    end

    test 'sort_proximity_geographic never emits an injected payload and coerces coordinates to float' do
      assert_not_includes(search.sort_proximity_geographic('ASC', [SQLI_COORD_PAYLOAD, '0']).to_sql, 'pg_sleep')
      assert_not_includes(search.sort_proximity_geographic('ASC', [SQLI_COORD_PAYLOAD, '0']).to_sql, 'geom_simple::geography <->')

      sql = search.sort_proximity_geographic('ASC', ['10.5', '47.25']).to_sql

      assert_includes(sql, "geometries.geom_simple::geography <-> 'SRID=4326;POINT (10.5 47.25)'::geography asc NULLS LAST")
    end

    test 'sort_by_proximity returns self without parseable dates' do
      base = search

      assert_same(base, base.sort_by_proximity('ASC', {}))
      assert_same(base, base.sort_by_proximity('ASC', { 'in' => {} }))
    end

    test 'sort_by_proximity orders by earliest occurrence in given range' do
      sql = search.sort_by_proximity('ASC', { 'in' => { 'min' => '2026-07-01', 'max' => '2026-07-31' } }).to_sql

      assert_includes(sql, 'MIN(LOWER(so.occurrence)) AS "min_start_date"')
      assert_includes(sql, "schedules.relation != 'validity_range'")
      assert_includes(sql, '.min_start_date asc NULLS LAST')
      assert_includes(search.sort_by_proximity('DESC', { 'v' => { 'from' => '2026-07-01' } }).to_sql, '.min_start_date desc NULLS LAST')
    end

    test 'sort_by_proximity filters by relation if given' do
      sql = search.sort_by_proximity('ASC', { 'in' => { 'min' => '2026-07-01' }, 'relation' => 'eventSchedule' }).to_sql

      assert_includes(sql, "schedules.relation = 'event_schedule'")
    end

    test 'sort_proximity_in_time orders by date diff to given absolute date' do
      sql = search.sort_proximity_in_time('ASC', { 'in' => { 'min' => '2026-07-01' } }).to_sql

      assert_includes(sql, "'end_date'")
      assert_includes(sql, "'start_date'")
      assert_includes(sql, "'2026-07-01'")
      assert_includes(search.sort_proximity_in_time('ASC', { 'v' => { 'from' => '2026-07-02' } }).to_sql, "'2026-07-02'")
    end

    test 'sort_proximity_in_time supports relative dates and empty values' do
      sql = search.sort_proximity_in_time('ASC', { 'q' => 'relative', 'in' => { 'min' => { 'n' => '2', 'unit' => 'day', 'mode' => 'p' } } }).to_sql

      assert_includes(sql, "'end_date'")

      sql = search.sort_proximity_in_time('ASC', { 'q' => 'relative', 'v' => { 'from' => { 'n' => '1', 'unit' => 'week', 'mode' => 'm' } } }).to_sql

      assert_includes(sql, "'start_date'")
      assert_includes(search.sort_proximity_in_time.to_sql, "'end_date'")
    end

    test 'sort_proximity_occurrence_with_distance returns self for invalid values' do
      base = search

      assert_same(base, base.sort_proximity_occurrence_with_distance('ASC', 'invalid'))
      assert_same(base, base.sort_proximity_occurrence_with_distance('ASC', []))
      assert_same(base, base.sort_proximity_occurrence_with_distance('ASC', [['10', nil]]))
      assert_same(base, base.sort_proximity_occurrence_with_distance('ASC', [[nil, '47']]))
    end

    test 'sort_proximity_occurrence_with_distance orders by occurrence and distance' do
      sql = search.sort_proximity_occurrence_with_distance('ASC', [['10', '47'], { 'in' => { 'min' => '2026-07-01', 'max' => '2026-07-31' } }]).to_sql

      assert_includes(sql, '1 AS "occurrence_exists"')
      assert_includes(sql, 'MIN(LOWER(so.occurrence))')
      assert_includes(sql, "schedules.relation != 'validity_range'")
      assert_includes(sql, "geometries.geom_simple::geography <-> 'SRID=4326;POINT (10.0 47.0)'::geography asc NULLS LAST")
      assert_includes(sql, '.min_start_date asc NULLS LAST')
      assert_includes(sql, '.occurrence_exists asc NULLS LAST')
    end

    test 'sort_proximity_occurrence_with_distance without schedule value uses defaults and supports DESC' do
      sql = search.sort_proximity_occurrence_with_distance('DESC', [['10', '47']]).to_sql

      assert_includes(sql, '.min_start_date desc NULLS LAST')
      assert_includes(sql, 'desc NULLS LAST')
    end

    test 'sort_proximity_occurrence_with_distance filters by relation if given' do
      sql = search.sort_proximity_occurrence_with_distance('ASC', [['10', '47'], { 'in' => { 'min' => '2026-07-01' }, 'relation' => 'eventSchedule' }]).to_sql

      assert_includes(sql, "schedules.relation = 'event_schedule'")
    end

    test 'sort_proximity_in_occurrence_with_distance does not order by occurrence start date' do
      sql = search.sort_proximity_in_occurrence_with_distance('ASC', [['10', '47'], { 'in' => { 'min' => '2026-07-01', 'max' => '2026-07-31' } }]).to_sql

      assert_includes(sql, 'ELSE 1 END as min_start_date')
      assert_includes(sql, "geometries.geom_simple::geography <-> 'SRID=4326;POINT (10.0 47.0)'::geography asc NULLS LAST")
    end

    test 'sort_proximity_in_occurrence orders by occurrences in given range' do
      sql = search.sort_proximity_in_occurrence('ASC', { 'in' => { 'min' => '2026-07-01', 'max' => '2026-07-31' } }).to_sql

      assert_includes(sql, 'INNER JOIN UNNEST(schedules.occurrences_array)')
      assert_includes(sql, 'MIN(LOWER(so.occurrence)) AS "min_start_date"')
      assert_includes(sql, "schedules.relation != 'validity_range'")
      assert_includes(sql, '.min_start_date asc NULLS LAST')
    end

    test 'sort_proximity_in_occurrence supports empty value, relation and DESC' do
      sql = search.sort_proximity_in_occurrence('DESC', { 'in' => { 'min' => '2026-07-01' }, 'relation' => 'eventSchedule' }).to_sql

      assert_includes(sql, "schedules.relation = 'event_schedule'")
      assert_includes(sql, '.min_start_date desc NULLS LAST')
      assert_includes(search.sort_proximity_in_occurrence('ASC').to_sql, '.occurrence_exists asc NULLS LAST')
    end

    test 'sort_proximity_in_occurrence_with_distance_pia returns self for invalid values' do
      base = search

      assert_same(base, base.sort_proximity_in_occurrence_with_distance_pia('ASC', 'invalid'))
      assert_same(base, base.sort_proximity_in_occurrence_with_distance_pia('ASC', []))
      assert_same(base, base.sort_proximity_in_occurrence_with_distance_pia('ASC', [['10', nil]]))
    end

    test 'sort_proximity_in_occurrence_with_distance_pia categorizes occurrences and orders by distance' do
      sql = search.sort_proximity_in_occurrence_with_distance_pia('ASC', [['10', '47'], { 'in' => { 'min' => '2026-07-01', 'max' => '2026-07-31' }, 'relation' => 'eventSchedule' }]).to_sql

      assert_includes(sql, 'THEN 2')
      assert_includes(sql, 'ELSE 3')
      assert_includes(sql, 'ELSE 1 END as min_start_date')
      assert_includes(sql, "schedules.relation = 'event_schedule'")
      assert_includes(sql, '.occurrence_exists asc NULLS LAST')
      assert_includes(sql, "geometries.geom_simple::geography <-> 'SRID=4326;POINT (10.0 47.0)'::geography asc NULLS LAST")
    end

    test 'sort_proximity_in_occurrence_with_distance_pia defaults to opening_hours_specification relation' do
      sql = search.sort_proximity_in_occurrence_with_distance_pia('DESC', [['10', '47']]).to_sql

      assert_includes(sql, "schedules.relation = 'opening_hours_specification'")
      assert_includes(sql, '.occurrence_exists desc NULLS LAST')
    end

    test 'sort_legacy_fulltext_search returns self for blank values' do
      base = search

      assert_same(base, base.sort_legacy_fulltext_search('DESC', nil))
      assert_same(base, base.sort_legacy_fulltext_search('DESC', ''))
    end

    test 'sort_legacy_fulltext_search orders by boosted similarity' do
      sql = search.sort_legacy_fulltext_search('DESC', 'Wolfgangsee Ruderboot').to_sql

      assert_includes(sql, "LEFT JOIN searches ON searches.content_data_id = things.id AND searches.locale = 'de'")
      assert_includes(sql, '8 * similarity(searches.classification_string')
      assert_includes(sql, '4 * similarity(searches.headline')
      assert_includes(sql, 'plainto_tsquery(pg_dict_mappings.dict')
      assert_includes(sql, 'desc NULLS LAST')
      assert_includes(search.sort_legacy_fulltext_search('ASC', 'Wolfgangsee').to_sql, 'asc NULLS LAST')
    end

    test 'sort_ts_rank_fulltext_search returns self for blank values' do
      base = search

      assert_same(base, base.sort_ts_rank_fulltext_search('DESC', nil))
      assert_same(base, base.sort_ts_rank_fulltext_search('DESC', { value: '', fields: nil }))
    end

    test 'sort_ts_rank_fulltext_search orders by ts_rank_cd' do
      sql = search.sort_ts_rank_fulltext_search('DESC', { value: 'Wolfgangsee Ruderboot', fields: nil }).to_sql

      assert_includes(sql, 'ts_rank_cd(')
      assert_includes(sql, 'websearch_to_prefix_tsquery')
      assert_includes(sql, 'desc NULLS LAST')
      assert_includes(search.sort_ts_rank_fulltext_search('ASC', 'Wolfgangsee').to_sql, 'asc NULLS LAST')
    end
  end
end
