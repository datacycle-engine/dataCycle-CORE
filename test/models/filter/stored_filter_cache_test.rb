# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StoredFilterCacheTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      create_content('Artikel', { name: 'AAA' })
      @stored_filter = DataCycleCore::StoredFilter.create(parameters: [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } }])
    end

    test 'cached false by default' do
      @stored_filter.rebuild_cache!
      @stored_filter.remove_cache!

      assert_not @stored_filter.cache_result?
      assert_not @stored_filter.cached_result?
      assert_equal 0, @stored_filter.stored_filter_caches.size
      assert_nil @stored_filter.cache_updated_at
      assert_equal 1, @stored_filter.things.size
    end

    test 'cached true creates cache' do
      @stored_filter.update(cache_ttl: 60)
      @stored_filter.cached

      assert_predicate @stored_filter, :cache_result?
      assert_predicate @stored_filter, :cached_result?
      assert_equal 1, @stored_filter.stored_filter_caches.size
      assert_predicate @stored_filter.cache_updated_at, :present?
      assert_equal 1, @stored_filter.things.size
    end

    test 'cache true creates cache, disable again removes it' do
      @stored_filter.update(cache_ttl: 60)
      @stored_filter.update(cache_ttl: 0)

      assert_not @stored_filter.cache_result?
      assert_not @stored_filter.cached_result?
      assert_equal 0, @stored_filter.stored_filter_caches.size
      assert_nil @stored_filter.cache_updated_at
      assert_equal 1, @stored_filter.things.size
    end

    test 'cached_result? is false when parameters changed' do
      @stored_filter.update(cache_ttl: 60)
      @stored_filter.cached

      assert_predicate @stored_filter, :cached_result?

      @stored_filter.parameters = [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Bild'] } }]

      assert_predicate @stored_filter, :parameters_changed?
      assert_predicate @stored_filter, :cache_result?
      assert_not @stored_filter.cached_result?
    end

    # Regression: applying a user filter must NOT dirty the persisted `parameters`, so a cachable filter
    # keeps serving from its cache while the user filter is applied live on top of the cached result.
    # (apply(...).query is used instead of #things to bypass #things' memoization between the two counts.)
    test 'user filter does not disable the cache and still restricts results' do
      current_user = User.find_by(email: 'tester@datacycle.at')
      previous_user_filters = DataCycleCore.user_filters.deep_dup
      DataCycleCore.user_filters = { tmp_cache: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'scope' => ['api'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person'] } }] } }

      filter = DataCycleCore::StoredFilter.create(cache_ttl: 60, parameters: [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } }])
      filter.cached

      assert_predicate filter, :cached_result?
      assert_equal 1, filter.cached.apply(skip_ordering: true).query.count

      filter.apply_user_filter(current_user, { scope: 'api' })

      assert_not filter.parameters_changed?, 'user filter must not dirty the persisted parameters'
      assert_predicate filter, :cached_result?
      assert_equal 1, filter.user_filter_parameters.size

      # the cached set (one Artikel) is served from cache, and the Person user filter is applied live on
      # top of it -> no content is both an Artikel and a Person, so the restricted result is empty.
      assert_equal 0, filter.cached.apply(skip_ordering: true).query.count
    ensure
      filter&.destroy
      DataCycleCore.user_filters = previous_user_filters
    end

    # Regression: a persisted filter whose `parameters` already contain a forced user-filter entry (e.g. a
    # legacy filter saved before user filters were kept out of `parameters`, or a manually-added equal
    # filter) must serve fully from cache when an eligible user reopens it - the entry is already enforced by
    # the cached set, so the matching user filter is not re-collected for live application and `parameters`
    # stays clean (cache stays valid).
    test 'reopening a filter whose parameters already carry an applicable forced user filter is a full cache hit' do
      current_user = User.find_by(email: 'tester@datacycle.at')
      previous_user_filters = DataCycleCore.user_filters.deep_dup
      DataCycleCore.user_filters = { tmp_baked: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['api'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } }] } }

      # resolve the forced user filter exactly as apply_user_filter would, then persist it directly into a
      # filter's `parameters` (the shape a legacy saved filter would have carried).
      baked = DataCycleCore::StoredFilter.new.apply_user_filter(current_user, { scope: 'api' }).user_filter_parameters

      assert_equal 1, baked.size
      assert_equal 'uf', baked.first['c']

      filter = DataCycleCore::StoredFilter.create(cache_ttl: 60, parameters: baked.deep_dup)
      filter.cached

      assert_predicate filter, :cached_result?
      assert_equal 1, filter.cached.apply(skip_ordering: true).query.count

      filter.apply_user_filter(current_user, { scope: 'api' })

      assert_empty filter.user_filter_parameters, 'persisted forced-filter entry must not be re-applied live on top of the cache'
      assert_not filter.parameters_changed?, 'persisted user-filter entry must not dirty the parameters'
      assert_predicate filter, :cached_result?
      assert_equal 1, filter.cached.apply(skip_ordering: true).query.count
    ensure
      filter&.destroy
      DataCycleCore.user_filters = previous_user_filters
    end

    # Regression: a second user opening a filter whose `parameters` already carry a forced user-filter entry
    # gets that (cached) result further restricted by their own live user filter - the persisted entry is
    # already enforced by the cache so it is not re-collected, the cache stays valid, and nothing is duplicated.
    test 'another user further restricts a cached result live without disabling the cache' do
      creator = User.find_by(email: 'tester@datacycle.at')
      other_user = User.find_by(email: 'admin@datacycle.at')
      previous_user_filters = DataCycleCore.user_filters.deep_dup

      # the forced "Artikel" filter applies to everyone ('all') and is present in the filter's persisted
      # `parameters` (and thus its cache), so it keeps applying to whoever opens it.
      creator_filter = { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['all'] }], 'force' => true, 'scope' => ['api'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } }] }
      DataCycleCore.user_filters = { tmp_creator: creator_filter }

      baked = DataCycleCore::StoredFilter.new.apply_user_filter(creator, { scope: 'api' }).user_filter_parameters

      assert_equal 1, baked.size
      assert_equal 'uf', baked.first['c']

      filter = DataCycleCore::StoredFilter.create(cache_ttl: 60, parameters: baked.deep_dup)
      filter.cached

      assert_predicate filter, :cached_result?
      assert_equal 1, filter.cached.apply(skip_ordering: true).query.count

      # the other user is additionally subject to their own forced "Person" filter (scoped to their role).
      other_filter = { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['super_admin'] }], 'force' => true, 'scope' => ['api'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person'] } }] }
      DataCycleCore.user_filters = { tmp_creator: creator_filter, tmp_other: other_filter }

      filter.apply_user_filter(other_user, { scope: 'api' })

      # the baked "Artikel" filter still applies to the other user, so it stays a full cache hit and is not
      # re-collected; only their own "Person" filter is applied live on top -> Artikel ∩ Person is empty.
      assert_equal 1, filter.user_filter_parameters.size
      assert_not filter.parameters_changed?, 'a live user filter must not dirty the persisted parameters'
      assert_predicate filter, :cached_result?
      assert_equal 0, filter.cached.apply(skip_ordering: true).query.count
    ensure
      filter&.destroy
      DataCycleCore.user_filters = previous_user_filters
    end

    # Regression: opening a filter whose `parameters` carry a user-filter entry (`u`/`uf`) that is NOT
    # applicable to the current user downgrades that entry's context to `a` (see
    # FilterParamsHashParser#apply_user_filter), dirtying `parameters`. That context-only change must NOT
    # invalidate the cache (the cached set is context-independent), so the user keeps serving from cache
    # instead of recomputing the base query live.
    test 'a context-only downgrade of a persisted user-filter entry does not invalidate the cache' do
      current_user = User.find_by(email: 'tester@datacycle.at')
      previous_user_filters = DataCycleCore.user_filters.deep_dup
      DataCycleCore.user_filters = { tmp_baked: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['api'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Artikel'] } }] } }

      baked = DataCycleCore::StoredFilter.new.apply_user_filter(current_user, { scope: 'api' }).user_filter_parameters
      filter = DataCycleCore::StoredFilter.create(cache_ttl: 60, parameters: baked.deep_dup)
      filter.cached

      assert_predicate filter, :cached_result?

      # a user for whom the baked filter is not applicable (here: no api user filters at all) opens the filter
      DataCycleCore.user_filters = {}
      filter.apply_user_filter(current_user, { scope: 'api' })

      # the persisted forced-filter entry was downgraded to a plain `a` context, dirtying the parameters ...
      assert_equal ['a'], filter.parameters.pluck('c')
      assert_predicate filter, :parameters_changed?
      # ... but that context-only change must not invalidate the cache, so it still serves from cache.
      assert_predicate filter, :cached_result?
      assert_equal 1, filter.cached.apply(skip_ordering: true).query.count
    ensure
      filter&.destroy
      DataCycleCore.user_filters = previous_user_filters
    end
  end
end
