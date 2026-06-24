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
  end
end
