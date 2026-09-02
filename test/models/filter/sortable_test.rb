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

    # #50091
    CLASSIFICATION_UUID = 'a1b2c3d4-1234-1234-1234-123456789abc'
    CLASSIFICATION_UUID_2 = 'b2c3d4e5-2345-2345-2345-23456789abcd'

    test 'sort_dc_classification orders by array_position over collected_classification_contents' do
      sql = search.sort_dc_classification('ASC', [CLASSIFICATION_UUID]).to_sql

      assert_includes(sql, 'LEFT OUTER JOIN')
      assert_includes(sql, 'collected_classification_contents')
      assert_includes(sql, 'array_position(ARRAY[')
      assert_includes(sql, "'#{CLASSIFICATION_UUID}'")
      assert_includes(sql, '::uuid[]')
      assert_includes(sql, 'hidden = false')
      assert_includes(sql, 'dc_classification_sort.sort_position asc NULLS LAST')
      assert_includes(search.sort_dc_classification('DESC', [CLASSIFICATION_UUID]).to_sql, 'dc_classification_sort.sort_position desc NULLS LAST')
    end

    test 'sort_dc_classification accepts a comma-separated string of uuids' do
      sql = search.sort_dc_classification('ASC', "#{CLASSIFICATION_UUID},#{CLASSIFICATION_UUID_2}").to_sql

      assert_includes(sql, "'#{CLASSIFICATION_UUID}'")
      assert_includes(sql, "'#{CLASSIFICATION_UUID_2}'")
    end

    test 'sort_dc_classification raises for blank or invalid uuids' do
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC', nil) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC', '') }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC', []) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC', ['not-a-uuid']) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC', "#{CLASSIFICATION_UUID},not-a-uuid") }
    end

    # #50091 security: the uuid? format check is the injection boundary for the value; every
    # non-UUID token must be rejected before it can reach the SQL string, so a crafted value
    # can never break out of the ARRAY[?]::uuid[] bind.
    test 'sort_dc_classification rejects sql injection payloads in the value' do
      [
        "'; DROP TABLE things; --",
        "#{CLASSIFICATION_UUID}'); DROP TABLE things; --",
        "#{CLASSIFICATION_UUID}') UNION SELECT id FROM active_storage_blobs --",
        "' OR '1'='1",
        '1); DELETE FROM collected_classification_contents; --',
        "#{CLASSIFICATION_UUID}]::text[]) --"
      ].each do |payload|
        assert_raises(DataCycleCore::Error::Api::InvalidArgumentError, "expected #{payload.inspect} to be rejected") do
          search.sort_dc_classification('ASC', payload)
        end
      end
    end

    # #50091 security: UUID_REGEX is anchored with \A...\z (not ^...$), so a value whose first
    # line looks like a UUID must still be rejected instead of smuggling a payload past it.
    test 'sort_dc_classification rejects a multiline value that hides a payload after a valid uuid' do
      payload = "#{CLASSIFICATION_UUID}\n'); DROP TABLE things; --"

      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC', payload) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC', [payload]) }
    end

    # #50091 security: a single poisoned element in an otherwise valid array must fail the whole sort.
    test 'sort_dc_classification rejects injection via a poisoned element in the uuid array' do
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) do
        search.sort_dc_classification('ASC', [CLASSIFICATION_UUID, "'; DROP TABLE things; --"])
      end
    end

    # #50091 security: the ordering direction is whitelisted (asc/desc only) via sanitized_ordering,
    # so it cannot inject into the ORDER BY clause.
    test 'sort_dc_classification rejects an injected ordering direction' do
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('ASC; DROP TABLE things; --', [CLASSIFICATION_UUID]) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_dc_classification('asc NULLS FIRST', [CLASSIFICATION_UUID]) }
    end

    # #50091 security: valid uuids are emitted only as quoted, ::uuid[]-cast literals, never spliced
    # raw into the SQL. Also guards against accidental introduction of string interpolation.
    test 'sort_dc_classification binds uuids as quoted, cast values' do
      sql = search.sort_dc_classification('ASC', [CLASSIFICATION_UUID]).to_sql

      assert_includes(sql, "ARRAY['#{CLASSIFICATION_UUID}']::uuid[]")
      assert_not_includes(sql, "ARRAY[#{CLASSIFICATION_UUID}]") # never unquoted
    end

    # #50554
    THING_UUID = 'c3d4e5f6-3456-3456-3456-3456789abcde'
    THING_UUID_2 = 'd4e5f6a7-4567-4567-4567-456789abcdef'

    test 'sort_id orders by array_position over things.id' do
      sql = search.sort_id('ASC', [THING_UUID, THING_UUID_2]).to_sql

      assert_includes(sql, "array_position(ARRAY['#{THING_UUID}','#{THING_UUID_2}']::uuid[], things.id) asc NULLS LAST")
      assert_includes(search.sort_id('DESC', [THING_UUID]).to_sql, 'things.id) desc NULLS LAST')
    end

    test 'sort_id accepts a comma-separated string of uuids' do
      sql = search.sort_id('ASC', "#{THING_UUID}, #{THING_UUID_2}").to_sql

      assert_includes(sql, "ARRAY['#{THING_UUID}','#{THING_UUID_2}']::uuid[]")
    end

    # #50554: without a list, @id is a plain sort on things.id instead of a silent no-op.
    test 'sort_id orders by things.id for a blank list' do
      [nil, '', []].each do |value|
        assert_includes(search.sort_id('ASC', value).to_sql, '"things"."id" ASC', "expected #{value.inspect} to sort by things.id")
      end

      assert_includes(search.sort_id('DESC').to_sql, '"things"."id" DESC')
      assert_not_includes(search.sort_id('ASC', nil).to_sql, 'array_position')
    end

    test 'sort_id raises for invalid uuids' do
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_id('ASC', ['not-a-uuid']) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_id('ASC', "#{THING_UUID},not-a-uuid") }
    end

    # #50554 security: same injection boundary as #50091 — every non-UUID token is rejected before it
    # can reach the ARRAY[?]::uuid[] literal, including a payload hidden behind a newline.
    test 'sort_id rejects sql injection payloads in the value' do
      [
        "'; DROP TABLE things; --",
        "#{THING_UUID}'); DROP TABLE things; --",
        "#{THING_UUID}') UNION SELECT id FROM active_storage_blobs --",
        "' OR '1'='1",
        '1); DELETE FROM things; --',
        "#{THING_UUID}]::text[]) --",
        "#{THING_UUID}\n'); DROP TABLE things; --"
      ].each do |payload|
        assert_raises(DataCycleCore::Error::Api::InvalidArgumentError, "expected #{payload.inspect} to be rejected") do
          search.sort_id('ASC', payload)
        end

        assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_id('ASC', [THING_UUID, payload]) }
      end
    end

    # #50554 security: the ordering direction is whitelisted in both branches (list and plain id sort).
    test 'sort_id rejects an injected ordering direction' do
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_id('ASC; DROP TABLE things; --', [THING_UUID]) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_id('asc NULLS FIRST', [THING_UUID]) }
      assert_raises(DataCycleCore::Error::Api::InvalidArgumentError) { search.sort_id('ASC; DROP TABLE things; --') }
    end
  end
end
