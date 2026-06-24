# frozen_string_literal: true

require 'test_helper'
require 'v4/helpers/dummy_data_helper'

module DataCycleCore
  module Sql
    class StoredSearchRepresentationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      include ActiveSupport::Testing::TimeHelpers

      before(:all) do
        cleanup_sql_test_data
      end

      after(:all) do
        cleanup_sql_test_data
      end

      test 'sql resolver returns watch list contents' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'SQL Watch List')
        DataCycleCore::WatchListDataHash.create!(watch_list_id: watch_list.id, thing_id: poi_a.id)
        DataCycleCore::WatchListDataHash.create!(watch_list_id: watch_list.id, thing_id: poi_b.id)

        assert_equal([poi_a.id, poi_b.id].sort, resolve_search_ids(watch_list.id), 'expected resolver to return watch list thing ids')
      end

      test 'sql resolver returns cached stored filter results when cache is fresh' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_poi_filter', cache_ttl: 60)
        stored_filter.stored_filter_caches.delete_all
        DataCycleCore::StoredFilterCache.create!(stored_filter_id: stored_filter.id, thing_id: poi_a.id)

        stored_filter.update_column(:cache_updated_at, Time.zone.now)
        stored_filter.sync_sql_representation!

        assert_equal([poi_a.id], resolve_search_ids(stored_filter.id), 'expected resolver to return cached stored filter ids when cache is fresh')
        assert_not_includes(resolve_search_ids(stored_filter.id), poi_b.id, 'expected resolver to return only cached ids when cache is fresh')
      end

      test 'sql resolver recomputes stored filter results when cache is stale' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_poi_filter', cache_ttl: 60)
        stored_filter.stored_filter_caches.delete_all
        DataCycleCore::StoredFilterCache.create!(stored_filter_id: stored_filter.id, thing_id: poi_a.id)

        stored_filter.update_column(:cache_updated_at, 2.hours.ago)
        stored_filter.sync_sql_representation!

        assert_equal([poi_a.id, poi_b.id].sort, resolve_search_ids(stored_filter.id), 'expected resolver to ignore stale cache and return full stored filter results')
      end

      test 'sql resolver ignores cache when cache_ttl is nil' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_poi_filter', cache_ttl: nil)
        stored_filter.stored_filter_caches.delete_all
        DataCycleCore::StoredFilterCache.create!(stored_filter_id: stored_filter.id, thing_id: poi_a.id)

        stored_filter.update_column(:cache_updated_at, Time.zone.now)
        stored_filter.sync_sql_representation!

        assert_equal([poi_a.id, poi_b.id].sort, resolve_search_ids(stored_filter.id), 'expected resolver to ignore cache when cache_ttl is nil')
      end

      test 'sql resolver ignores cache when cache_ttl is zero' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_poi_filter', cache_ttl: 0)
        stored_filter.stored_filter_caches.delete_all
        DataCycleCore::StoredFilterCache.create!(stored_filter_id: stored_filter.id, thing_id: poi_a.id)

        stored_filter.update_column(:cache_updated_at, Time.zone.now)
        stored_filter.sync_sql_representation!

        assert_equal([poi_a.id, poi_b.id].sort, resolve_search_ids(stored_filter.id), 'expected resolver to ignore cache when cache_ttl is zero')
      end

      test 'sql resolver cache-freshness window matches the Ruby cached_result? grace boundary' do
        grace = DataCycleCore::StoredFilterExtensions::Cachable::CACHE_VALIDITY_GRACE_MINUTES
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_cache_parity', cache_ttl: 60)
        stored_filter.stored_filter_caches.delete_all
        DataCycleCore::StoredFilterCache.create!(stored_filter_id: stored_filter.id, thing_id: poi_a.id)
        stored_filter.sync_sql_representation!

        stored_filter.update_column(:cache_updated_at, (60 + grace - 5).minutes.ago)

        assert_predicate(stored_filter.cached(true), :cached_result?, 'expected Ruby to treat a cache within the grace window as fresh')
        assert_equal([poi_a.id], resolve_search_ids(stored_filter.id), 'expected the SQL resolver to use the cache within the grace window')

        stored_filter.update_column(:cache_updated_at, (60 + grace + 5).minutes.ago)

        assert_not_predicate(stored_filter.cached(true), :cached_result?, 'expected Ruby to treat a cache beyond the grace window as stale')
        assert_equal([poi_a.id, poi_b.id].sort, resolve_search_ids(stored_filter.id), 'expected the SQL resolver to recompute live beyond the grace window')
      end

      test 'sql resolver evaluates relative schedule filters' do
        base_time = Time.zone.now
        event_in_range = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
        schedule_in_range = DataCycleCore::TestPreparations
          .generate_schedule(base_time + 1.day, base_time + 2.days, 1.hour)
          .serialize_schedule_object
        event_in_range.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_in_range.schedule_object.to_hash] })

        event_outside_range = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
        schedule_outside_range = DataCycleCore::TestPreparations
          .generate_schedule(base_time + 11.days, base_time + 12.days, 1.hour)
          .serialize_schedule_object
        event_outside_range.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_outside_range.schedule_object.to_hash] })

        relative_filter = DataCycleCore::StoredFilter.create(
          name: 'sql_relative_schedule',
          user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
          language: ['de'],
          parameters: [{
            'c' => 'a',
            'm' => 'i',
            'n' => 'event_schedule',
            'q' => 'relative',
            't' => 'in_schedule',
            'v' => {
              'from' => { 'n' => 0, 'unit' => 'day', 'mode' => 'p' },
              'until' => { 'n' => 10, 'unit' => 'day', 'mode' => 'p' }
            }
          }],
          api: true
        )
        relative_filter.sync_sql_representation!

        assert_equal([event_in_range.id], resolve_search_ids(relative_filter.id), 'expected resolver to apply relative schedule window')
        assert_not_includes(resolve_search_ids(relative_filter.id), event_outside_range.id, 'expected resolver to exclude events outside relative schedule window')
      end

      test 'sql resolver applies relative schedule across midnight boundary' do
        base_time = Time.zone.now
        event_in_range = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
        schedule_in_range = DataCycleCore::TestPreparations
          .generate_schedule(base_time + 30.minutes, base_time + 2.hours, 1.hour)
          .serialize_schedule_object
        event_in_range.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_in_range.schedule_object.to_hash] })

        event_outside_range = DataCycleCore::V4::DummyDataHelper.create_data('minimal_event')
        schedule_outside_range = DataCycleCore::TestPreparations
          .generate_schedule(base_time - 1.hour, base_time - 30.minutes, 30.minutes)
          .serialize_schedule_object
        event_outside_range.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_outside_range.schedule_object.to_hash] })

        relative_filter = DataCycleCore::StoredFilter.create(
          name: 'sql_relative_midnight',
          user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
          language: ['de'],
          parameters: [{
            'c' => 'a',
            'm' => 'i',
            'n' => 'event_schedule',
            'q' => 'relative',
            't' => 'in_schedule',
            'v' => {
              'from' => { 'n' => 0, 'unit' => 'day', 'mode' => 'p' },
              'until' => { 'n' => 1, 'unit' => 'day', 'mode' => 'p' }
            }
          }],
          api: true
        )
        relative_filter.sync_sql_representation!

        assert_equal([event_in_range.id], resolve_search_ids(relative_filter.id), 'expected relative window to include only upcoming events')
        assert_not_includes(resolve_search_ids(relative_filter.id), event_outside_range.id, 'expected relative window to exclude past events even if within 24 hours')
      end

      test 'sql resolver returns empty when stored filter matches nothing' do
        unique_name = "SQL Empty #{SecureRandom.uuid}"
        DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = DataCycleCore::StoredFilter.create(
          name: 'sql_empty_filter',
          user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
          language: ['de'],
          parameters: [{
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => unique_name
          }],
          api: true
        )

        stored_filter.sync_sql_representation!

        assert_equal([], resolve_search_ids(stored_filter.id), 'expected resolver to return an empty set when no items match')
      end

      test 'resolver resolves to the correct results' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_poi_filter')

        stored_filter.sync_sql_representation!

        expected_ids = resolve_search_ids(stored_filter.id)
        named_ids = function_ids(stored_filter.sql_representation_name)

        assert_equal([poi_a.id, poi_b.id].sort, expected_ids, 'expected resolver to return both POI ids')
        assert_equal(expected_ids, named_ids, 'expected resolver to return same ids as a direct call to the named SQL representation')
      end

      test 'resolver returns empty set for undefined (missing or dropped) SQL representation' do
        DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_missing', cache_ttl: nil)
        stored_filter.stored_filter_caches.delete_all
        stored_filter.update_column(:cache_updated_at, 2.hours.ago)

        stored_filter.drop_sql_representation!

        assert_equal([], resolve_search_ids(stored_filter.id), 'expected resolver to return empty when per-filter SQL missing')
      end

      test 'resolver returns empty for non-existent collection' do
        assert_equal([], resolve_search_ids(SecureRandom.uuid), 'expected resolver to return empty for unknown collection id')
      end

      test 'resolver returns empty set for collections.type with any values other than watchlist or storedfilter' do
        id = SecureRandom.uuid
        ActiveRecord::Base.connection.execute(%{INSERT INTO public.collections (id, type) VALUES ('#{id}'::uuid, 'DataCycleCore::Unrelated')})

        assert_equal([], resolve_search_ids(id), 'expected resolver to return empty for non-watchlist/non-storedfilter types')
      ensure
        begin
          ActiveRecord::Base.connection.execute(%(DELETE FROM public.collections WHERE id = '#{id}'::uuid))
        rescue StandardError
          nil
        end
      end

      test 'updating a stored filter rewrites its generated SQL definition (its source code)' do
        DataCycleCore::V4::DummyDataHelper.create_data('poi')

        stored_filter = build_poi_filter(name: 'sql_filter_definition_update')
        stored_filter.sync_sql_representation!
        before_def = sql_definition(stored_filter.sql_representation_name)
        old_alias_id = DataCycleCore::ClassificationAlias.find_by(name: 'POI').id

        assert_predicate(before_def, :present?, 'expected SQL definition to exist before update')
        assert_includes(before_def, old_alias_id, 'expected before definition to include previous classification filter')

        new_value = SecureRandom.uuid
        stored_filter.update!(
          parameters: [{
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => new_value
          }]
        )
        after_def = sql_definition(stored_filter.sql_representation_name)

        assert_predicate(after_def, :present?, 'expected SQL definition to exist after update')
        assert_not_equal(before_def, after_def, 'expected SQL definition to change after filter update')
        assert_includes(after_def, new_value, 'expected after definition to include new search term')
        assert_not_includes(before_def, new_value, 'expected before definition to exclude new search term')
      end

      test 'updating a stored filter changes the results returned by its SQL representation' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')

        stored_filter = build_poi_filter(name: 'sql_update')

        initial_ids = function_ids(stored_filter.sql_representation_name)

        assert_equal([poi_a.id, poi_b.id].sort, initial_ids, 'expected initial SQL representation to match stored filter results')

        stored_filter.update!(
          parameters: [{
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => SecureRandom.uuid
          }]
        )

        updated_ids = function_ids(stored_filter.sql_representation_name)

        assert_equal([], updated_ids, 'expected SQL representation to update after filter changes')
      end

      test 'generated stored filter SQL representation matches Ruby query results' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_generated_representation')

        stored_filter.sync_sql_representation!

        ruby_ids = stored_filter.cached(false).apply(skip_ordering: true).select(:id).pluck(:id).sort
        sql_ids = function_ids(stored_filter.sql_representation_name)

        assert_equal([poi_a.id, poi_b.id].sort, ruby_ids, 'expected Ruby query to return both POI ids')
        assert_equal(ruby_ids, sql_ids, 'expected generated SQL representation to match Ruby query')
      end

      test 'relative_date(jsonb) matches relative_to_absolute_date' do
        cases = [
          { name: 'nil value', value: nil },
          { name: 'missing n', value: {} },
          { name: 'blank n', value: { 'n' => '' } },
          { name: 'default unit day', value: { 'n' => 1, 'mode' => 'p' } },
          { name: 'minute future', value: { 'n' => 30, 'unit' => 'minute', 'mode' => 'p' } },
          { name: 'hour future', value: { 'n' => 2, 'unit' => 'hour', 'mode' => 'p' } },
          { name: 'day future', value: { 'n' => 1, 'unit' => 'day', 'mode' => 'p' } },
          { name: 'week future', value: { 'n' => 1, 'unit' => 'week', 'mode' => 'p' } },
          { name: 'month future', value: { 'n' => 1, 'unit' => 'month', 'mode' => 'p' } },
          { name: 'year future', value: { 'n' => 1, 'unit' => 'year', 'mode' => 'p' } },
          { name: 'minute past default mode', value: { 'n' => 15, 'unit' => 'minute' } },
          { name: 'hour past', value: { 'n' => 2, 'unit' => 'hour', 'mode' => 'x' } },
          { name: 'zero distance', value: { 'n' => 0, 'unit' => 'day', 'mode' => 'p' } },
          { name: 'negative distance', value: { 'n' => -1, 'unit' => 'day', 'mode' => 'p' } }
        ]

        cases.each do |entry|
          db_now = ActiveRecord::Base.connection.select_value('SELECT now()')
          db_now = db_now.is_a?(Time) ? db_now.in_time_zone : Time.zone.parse(db_now)

          ruby_value = travel_to db_now do
            DataCycleCore::Filter::Common::Date.relative_to_absolute_date(entry[:value])
          end
          json_value = entry[:value].nil? ? 'NULL' : ActiveRecord::Base.connection.quote(entry[:value].to_json)
          result = ActiveRecord::Base.connection.select_value("SELECT public.relative_date(#{json_value}::jsonb)")
          sql_value = result.nil? ? nil : result.is_a?(Time) ? result.in_time_zone : Time.zone.parse(result) # rubocop:disable Style/NestedTernaryOperator

          if ruby_value.nil?
            assert_nil(sql_value, "expected SQL to return nil for #{entry[:name]}")
          else
            assert_in_delta(ruby_value, sql_value, 2, "expected SQL to match Ruby for #{entry[:name]}")
          end
        end
      end

      test 'relative_date(jsonb) returns expected timestamptz for units and directions' do
        db_now = ActiveRecord::Base.connection.select_value('SELECT now()')
        db_now = db_now.is_a?(Time) ? db_now.in_time_zone : Time.zone.parse(db_now)

        day = ActiveRecord::Base.connection.select_value(%{SELECT public.relative_date('{"n":1,"unit":"day","mode":"p"}'::jsonb)})
        day = day.is_a?(Time) ? day.in_time_zone : Time.zone.parse(day)

        assert_in_delta(db_now + 1.day, day, 1, 'relative_date +1 day')

        hour = ActiveRecord::Base.connection.select_value(%{SELECT public.relative_date('{"n":2,"unit":"hour","mode":"p"}'::jsonb)})
        hour = hour.is_a?(Time) ? hour.in_time_zone : Time.zone.parse(hour)

        assert_in_delta(db_now + 2.hours, hour, 1, 'relative_date +2 hours')

        minute = ActiveRecord::Base.connection.select_value(%{SELECT public.relative_date('{"n":30,"unit":"minute","mode":"p"}'::jsonb)})
        minute = minute.is_a?(Time) ? minute.in_time_zone : Time.zone.parse(minute)

        assert_in_delta(db_now + 30.minutes, minute, 1, 'relative_date +30 minutes')

        past = ActiveRecord::Base.connection.select_value(%{SELECT public.relative_date('{"n":1,"unit":"day","mode":"x"}'::jsonb)})
        past = past.is_a?(Time) ? past.in_time_zone : Time.zone.parse(past)

        assert_in_delta(db_now - 1.day, past, 1, 'relative_date with non-"p" mode -> past')
      end

      test 'Grafana-style aggregate query can filter by stored search results and aggregate by template' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_grafana_aggregate')
        stored_filter.sync_sql_representation!

        results = execute_search_aggregate(stored_filter.id)

        assert_equal(1, results.size, 'expected a single template bucket for POI results')
        assert_equal('POI', results.first['template_name'])
        assert_equal(2, results.first['count'])
        assert_equal([poi_a.id, poi_b.id].sort, resolve_search_ids(stored_filter.id), 'expected stored search ids to match POI fixtures')
      end

      test 'Grafana-style aggregate query returns empty when no ids match' do
        unique_name = "SQL Grafana Empty #{SecureRandom.uuid}"
        DataCycleCore::V4::DummyDataHelper.create_data('poi')

        stored_filter = DataCycleCore::StoredFilter.create(
          name: 'sql_grafana_empty_aggregate',
          user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
          language: ['de'],
          parameters: [{
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => unique_name
          }],
          api: true
        )
        stored_filter.sync_sql_representation!

        results = execute_search_aggregate(stored_filter.id)

        assert_equal([], results, 'expected no aggregate rows when stored search returns empty')
      end

      test 'Grafana-style rows query can filter by stored search results and returns selected columns' do
        poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
        stored_filter = build_poi_filter(name: 'sql_grafana_rows')
        stored_filter.sync_sql_representation!

        rows = execute_search_rows(stored_filter.id)

        assert_equal(2, rows.size, 'expected two rows for POI results')
        assert_equal([poi_a.id, poi_b.id].sort, rows.pluck('id').sort)
        assert_equal(['POI'], rows.pluck('template_name').uniq)
        assert(rows.pluck('created_at').all?(&:present?), 'expected created_at to be present for all rows')
      end

      test 'Grafana-style rows query returns empty when no ids match' do
        unique_name = "SQL Grafana Empty Rows #{SecureRandom.uuid}"
        DataCycleCore::V4::DummyDataHelper.create_data('poi')

        stored_filter = DataCycleCore::StoredFilter.create(
          name: 'sql_grafana_empty_rows',
          user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
          language: ['de'],
          parameters: [{
            'n' => 'Suchbegriff',
            't' => 'fulltext_search',
            'v' => unique_name
          }],
          api: true
        )
        stored_filter.sync_sql_representation!

        rows = execute_search_rows(stored_filter.id)

        assert_equal([], rows, 'expected no rows when stored search returns empty')
      end

      private

      def build_poi_filter(name:, cache_ttl: nil)
        DataCycleCore::StoredFilter.create(
          name:,
          user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
          language: ['de'],
          parameters: [{
            'c' => 'd',
            'm' => 'i',
            'n' => 'Inhaltstypen',
            't' => 'classification_alias_ids',
            'v' => [DataCycleCore::ClassificationAlias.find_by(name: 'POI').id]
          }],
          cache_ttl:,
          api: true
        )
      end

      def sql_definition(function_name)
        ActiveRecord::Base.connection.select_value(<<~SQL.squish)
          SELECT pg_get_functiondef(pg_proc.oid)
          FROM pg_proc
          JOIN pg_namespace ON pg_namespace.oid = pg_proc.pronamespace
          WHERE pg_namespace.nspname = 'public'
            AND pg_proc.proname = '#{function_name}'
          LIMIT 1
        SQL
      end

      def function_ids(function_name)
        ActiveRecord::Base.connection.select_values("SELECT * FROM public.#{function_name}()").sort
      end

      def resolve_search_ids(search_id)
        ActiveRecord::Base.connection.select_values("SELECT * FROM public.resolve_stored_search('#{search_id}'::uuid)").sort
      end

      def execute_search_aggregate(search_id)
        base_sql = stored_search_base_sql(search_id)

        ActiveRecord::Base.connection.select_all(<<~SQL.squish).to_a
          SELECT base.template_name, COUNT(DISTINCT base.id)::int AS count
          FROM (#{base_sql}) base
          GROUP BY base.template_name
          ORDER BY base.template_name ASC
        SQL
      end

      def execute_search_rows(search_id)
        base_sql = stored_search_base_sql(search_id)

        ActiveRecord::Base.connection.select_all(<<~SQL.squish).to_a
          SELECT base.id, base.template_name, base.created_at
          FROM (#{base_sql}) base
          ORDER BY base.id ASC
        SQL
      end

      # Returns the base SQL used by the Grafana-style tests. It mirrors how the dashboard
      # templates anchor a query on a stored search: every panel restricts `things` to the
      # current, non-embedded contents and applies the search as a semi-join on the resolver
      # (`t.id IN (SELECT public.resolve_stored_search(...))`).
      def stored_search_base_sql(search_id)
        stored_filter = DataCycleCore::StoredFilter.find(search_id)

        <<~SQL.squish
          SELECT t.id, t.template_name, t.created_at
          FROM things t
          INNER JOIN thing_templates tt ON t.template_name = tt.template_name
          WHERE t.deleted_at IS NULL
            AND tt.content_type = 'entity'
            AND t.id IN (SELECT public.resolve_stored_search('#{stored_filter.id}'::uuid))
        SQL
      end

      def cleanup_sql_test_data
        DataCycleCore::WatchListDataHash.delete_all
        DataCycleCore::StoredFilterCache.delete_all
        DataCycleCore::StoredFilter.delete_all
        DataCycleCore::WatchList.delete_all
        DataCycleCore::Collection.where(type: ['DataCycleCore::WatchList', 'DataCycleCore::StoredFilter']).delete_all
        DataCycleCore::Thing.delete_all
      end
    end
  end
end
