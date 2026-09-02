# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/cleanup_helper'

module DataCycleCore
  class CleanupHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ItemStub = Struct.new(:config)

    test 'identify_external_source returns nil when the config is blank' do
      assert_nil CleanupHelper.identify_external_source(ItemStub.new(nil))
    end

    test 'identify_external_source extracts the module name from the endpoint' do
      item = ItemStub.new(
        {
          'download_config' => {
            'places' => { 'endpoint' => 'DataCycleCore::Generic::Feratel::Endpoint' }
          }
        }
      )

      assert_equal 'Feratel', CleanupHelper.identify_external_source(item)
    end

    test 'linked returns nil for an unknown external source' do
      assert_nil CleanupHelper.linked('UnknownSystem')
    end

    test 'linked resolves linked templates via template_name and stored_filter' do
      thing = Object.new
      thing.define_singleton_method(:linked_property_names) { ['by_template', 'by_filter', 'neither'] }
      thing.define_singleton_method(:properties_for) do |name|
        case name
        when 'by_template' then { 'template_name' => 'POI' }
        when 'by_filter' then { 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'aliases' => ['Event', 'Tour'] } }] }
        else {}
        end
      end

      result = DataCycleCore::Thing.stub(:new, thing) do
        CleanupHelper.linked('MediaArchive')
      end

      assert_includes result, { relation: 'by_template', template: 'POI' }
      assert_includes result, { relation: 'by_filter', template: 'Event' }
      assert_includes result, { relation: 'by_filter', template: 'Tour' }
    end

    test 'embedded returns a mapping of embedded templates to their parents' do
      result = CleanupHelper.embedded

      assert_kind_of Hash, result
      result.each_value { |parents| assert_kind_of Array, parents }
    end

    test 'orphaned_embedded builds a relation filtering out linked things' do
      relation = CleanupHelper.orphaned_embedded(['POI'], 'Bild')

      assert_respond_to relation, :to_sql
      assert_nothing_raised { relation.limit(1).to_a }
    end

    test 'orphan_filter_parameters with neither mode restricts to the template only' do
      params = CleanupHelper.orphan_filter_parameters(template_name: 'POI')

      assert_equal ['template_names'], params.pluck('t')
      assert_equal ['POI'], params.first['v']
    end

    test 'orphan_filter_parameters in excludes mode adds imported-content and external_source exclude' do
      params = CleanupHelper.orphan_filter_parameters(template_name: 'Organization', exclude_source_ids: [1, 2])

      assert_equal ['template_names', 'boolean', 'external_source'], params.pluck('t')

      boolean = params.find { |p| p['t'] == 'boolean' }

      assert_equal 'with_external_source', boolean['n']
      assert_equal 'true', boolean['v']

      external = params.find { |p| p['t'] == 'external_source' }

      assert_equal 'e', external['m']
      assert_equal [1, 2], external['v']
    end

    test 'orphan_filter_parameters keeps excludes mode for an empty exclude list (clean in ALL systems)' do
      params = CleanupHelper.orphan_filter_parameters(template_name: 'Audio', exclude_source_ids: [])

      assert_equal ['template_names', 'boolean', 'external_source'], params.pluck('t')
      assert_equal [], params.find { |p| p['t'] == 'external_source' }['v']
    end

    test 'orphan_filter_parameters in base mode adds a filter_ids include' do
      params = CleanupHelper.orphan_filter_parameters(template_name: 'POI', base_filter_ids: ['a-uuid'])

      assert_equal ['template_names', 'filter_ids'], params.pluck('t')

      filter_ids = params.find { |p| p['t'] == 'filter_ids' }

      assert_equal 'i', filter_ids['m']
      assert_equal ['a-uuid'], filter_ids['v']
    end

    test 'orphan_filter_parameters combines both modes when both are given' do
      params = CleanupHelper.orphan_filter_parameters(template_name: 'POI', exclude_source_ids: [1], base_filter_ids: ['a-uuid'])

      assert_equal ['template_names', 'boolean', 'external_source', 'filter_ids'], params.pluck('t')
    end

    test 'orphan_filter_parameters omits filter_ids when base_filter_ids is blank' do
      params = CleanupHelper.orphan_filter_parameters(template_name: 'POI', base_filter_ids: [])

      assert_not_includes params.pluck('t'), 'filter_ids'
    end

    test 'with_deadlock_retry runs the block once and returns true on success' do
      calls = 0
      result = CleanupHelper.with_deadlock_retry { calls += 1 }

      assert result
      assert_equal 1, calls
    end

    test 'with_deadlock_retry retries on ActiveRecord::Deadlocked and eventually succeeds' do
      calls = 0

      result = CleanupHelper.stub(:sleep, nil) do
        CleanupHelper.with_deadlock_retry(max_tries: 5) do
          calls += 1
          raise ActiveRecord::Deadlocked, 'deadlock detected' if calls < 3
        end
      end

      assert result
      assert_equal 3, calls
    end

    test 'with_deadlock_retry gives up after max_tries and returns false' do
      calls = 0

      result = CleanupHelper.stub(:sleep, nil) do
        CleanupHelper.with_deadlock_retry(max_tries: 3) do
          calls += 1
          raise ActiveRecord::Deadlocked, 'deadlock detected'
        end
      end

      assert_not result
      assert_equal 3, calls
    end

    test 'with_deadlock_retry does not rescue unrelated errors' do
      calls = 0

      assert_raises(ArgumentError) do
        CleanupHelper.with_deadlock_retry do
          calls += 1
          raise ArgumentError, 'nope'
        end
      end

      assert_equal 1, calls
    end

    # dc:clean_up:archive_orphans (#37010): imported records that no longer have any incoming link
    # are archived instead of deleted. "No longer delivered" alone is not enough as a criterion —
    # a merged record carries several external keys, and the one that named it can retire while
    # other keys (and links) are still live.
    class ArchiveOrphansTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @external_system = DataCycleCore::ExternalSystem.find_by(identifier: 'base-system')
      end

      # external_hashes has a foreign key onto things (external_source_id, external_key), so a
      # delivery record only ever exists for a content's own primary key.
      def imported_article(name:, external_key:, seen_at: 10.days.ago)
        content = DataCycleCore::TestPreparations.create_content(
          template_name: 'Artikel',
          data_hash: { 'name' => name, 'external_key' => external_key, 'external_source_id' => @external_system.id }
        )

        DataCycleCore::ExternalHash.create!(
          external_source_id: @external_system.id, external_key:, locale: 'de', seen_at:
        )

        content
      end

      def link_to(content, suffix = '')
        linking = DataCycleCore::TestPreparations.create_content(
          template_name: 'Artikel', data_hash: { 'name' => "linking-#{content.external_key}#{suffix}" }
        )
        DataCycleCore::ContentContent.create!(content_a_id: linking.id, content_b_id: content.id, relation_a: 'related_to')
        linking
      end

      def scope
        DataCycleCore::Thing.where(template_name: 'Artikel')
      end

      # the dummy app configures the life-cycle stages but no archive_name, so resolve it the way
      # the vcloud instances do (see test/models/feature/under_ninety_features_coverage_test.rb)
      def with_archive_stage(&)
        DataCycleCore::Feature::LifeCycle.stub(:archive_name, ->(*) { 'Archiv' }, &)
      end

      test 'orphaned_imported returns unlinked content that has not been delivered for min_age_days' do
        orphan = imported_article(name: 'archive-orphan-stale', external_key: 'ao-stale')

        assert_includes CleanupHelper.orphaned_imported(scope, min_age_days: 3).pluck(:id), orphan.id
      end

      test 'orphaned_imported keeps content that was delivered inside the grace period' do
        fresh = imported_article(name: 'archive-orphan-fresh', external_key: 'ao-fresh', seen_at: 1.day.ago)

        assert_not_includes CleanupHelper.orphaned_imported(scope, min_age_days: 3).pluck(:id), fresh.id
      end

      # the merge case: a merged record keeps the surviving primary key, so once that source retires
      # it looks undelivered - only the link check keeps it out of the archive
      test 'orphaned_imported never returns linked content, however stale' do
        linked = imported_article(name: 'archive-orphan-linked', external_key: 'ao-linked', seen_at: 99.days.ago)
        link_to(linked)

        assert_not_includes CleanupHelper.orphaned_imported(scope, min_age_days: 3).pluck(:id), linked.id
      end

      test 'orphaned_imported returns content that has no delivery record at all' do
        never_seen = DataCycleCore::TestPreparations.create_content(
          template_name: 'Artikel',
          data_hash: { 'name' => 'archive-orphan-unseen', 'external_key' => 'ao-unseen', 'external_source_id' => @external_system.id }
        )

        assert_includes CleanupHelper.orphaned_imported(scope, min_age_days: 3).pluck(:id), never_seen.id
      end

      test 'orphaned_imported ignores content that was not imported' do
        local = DataCycleCore::TestPreparations.create_content(
          template_name: 'Artikel', data_hash: { 'name' => 'archive-orphan-local' }
        )

        assert_not_includes CleanupHelper.orphaned_imported(scope, min_age_days: 3).pluck(:id), local.id
      end

      test 'reattached returns linked content once, unlinked content never' do
        linked = imported_article(name: 'reattach-linked', external_key: 'ra-linked')
        link_to(linked, '-a')
        link_to(linked, '-b')
        orphan = imported_article(name: 'reattach-orphan', external_key: 'ra-orphan')

        ids = CleanupHelper.reattached(scope).pluck(:id)

        assert_equal 1, ids.count(linked.id)
        assert_not_includes ids, orphan.id
      end

      def sorted_collection
        DataCycleCore::StoredFilter.new(language: ['de'], sort_parameters: [{ 'm' => 'name', 'o' => 'ASC' }])
      end

      # the scope dc:clean_up:archive_orphans builds
      test 'the unsorted things of a stored filter survive the DISTINCT pass' do
        scope = sorted_collection.unsorted_things.where(template_name: ['Artikel'])

        assert_nothing_raised { CleanupHelper.reattached(scope).first }
      end

      # why the task asks for the unsorted things: the DISTINCT of #reattached next to the filter's
      # ORDER BY thing_translations.content ->> 'name' is rejected by Postgres, so any instance that
      # sorted its cleanup filter by name would have broken on the first run
      test 'the sorted things of a stored filter cannot be combined with the DISTINCT pass' do
        scope = sorted_collection.things.where(template_name: ['Artikel'])

        error = assert_raises(ActiveRecord::StatementInvalid) { CleanupHelper.reattached(scope).first }

        assert_match 'SELECT DISTINCT', error.message
      end

      test 'archive_contents! archives instead of destroying and is idempotent' do
        orphan = imported_article(name: 'archive-me', external_key: 'ao-archive')

        with_archive_stage do
          assert_equal 1, CleanupHelper.archive_contents!(DataCycleCore::Thing.where(id: orphan.id))
          assert_predicate orphan.reload, :archived?
          assert_equal 0, CleanupHelper.archive_contents!(DataCycleCore::Thing.where(id: orphan.id))
        end

        assert_predicate DataCycleCore::Thing.find_by(id: orphan.id), :present?
      end

      test 'reactivate_contents! only touches archived content' do
        archived = imported_article(name: 'reactivate-me', external_key: 'ao-reactivate')
        active = imported_article(name: 'stay-active', external_key: 'ao-active')

        with_archive_stage do
          CleanupHelper.archive_contents!(DataCycleCore::Thing.where(id: archived.id))

          assert_equal 1, CleanupHelper.reactivate_contents!(DataCycleCore::Thing.where(id: [archived.id, active.id]), stage_name: 'Aktuelle Inhalte')
          assert_not_predicate archived.reload, :archived?
        end
      end
    end
  end
end
