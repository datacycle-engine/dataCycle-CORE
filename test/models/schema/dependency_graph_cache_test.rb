# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # DependencyGraph.cached swaps the live presenter object for a plain-data Snapshot
  # on a cache hit. That substitution is invisible at the call site (the view keeps
  # calling #rows/#stats/#edge_count/#to_graph), which is exactly why it needs its
  # own coverage: every failure mode here only shows up on the SECOND page view.
  #
  # - a reader the Snapshot does not implement raises NoMethodError, but only once
  #   the cache is warm -- never in a fresh test run, never on the first request
  #   after a deploy
  # - a cache key that ignores locale or overlay_names serves the wrong page to the
  #   next visitor
  # - a key that never changes serves a stale graph until the TTL runs out
  class DependencyGraphCacheTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @schema = DataCycleCore::Schema.load_schema_from_database
      @live = DataCycleCore::Schema::DependencyGraph.new(
        schema: @schema, locale: I18n.default_locale, thing_counts: {}, overlay_names: []
      )
    end

    setup do
      Rails.cache.clear
    end

    def cached(locale: I18n.default_locale, thing_counts: {}, overlay_names: [])
      DataCycleCore::Schema::DependencyGraph.cached(schema: @schema, locale:, thing_counts:, overlay_names:)
    end

    # The whole point of the Snapshot: the view must not care which of the two it
    # got. Checked against the live object rather than a literal, so the assertion
    # tracks the schema instead of drifting from it.
    test 'a cold call answers exactly what the live graph would' do
      snapshot = cached

      assert_equal @live.rows, snapshot.rows
      assert_equal @live.stats, snapshot.stats
      assert_equal @live.edge_count, snapshot.edge_count
      assert_equal @live.to_graph, snapshot.to_graph
    end

    # …and so must the warm one. Rebuilding is blocked outright here: if the
    # Snapshot were missing a reader, or the cached payload could not be rehydrated,
    # this is where it surfaces.
    test 'a warm call serves the same answers without rebuilding the graph' do
      cold = cached

      DataCycleCore::Schema::DependencyGraph.stub(:new, ->(**) { raise 'rebuilt despite a warm cache' }) do
        warm = cached

        assert_equal cold.rows, warm.rows
        assert_equal cold.stats, warm.stats
        assert_equal cold.edge_count, warm.edge_count
        assert_equal cold.to_graph, warm.to_graph
      end
    end

    # The reader set the views actually use -- pinned so a rename on the live object
    # cannot leave the Snapshot behind (the failure would be deferred to a warm
    # cache, see the class comment).
    test 'the snapshot answers every reader the views call on the live graph' do
      snapshot = cached

      [:rows, :stats, :edge_count, :to_graph].each do |reader|
        assert_respond_to @live, reader
        assert_respond_to snapshot, reader
      end
    end

    # The tiles are rendered by iterating stats and looking up
    # "…dependencies.stats.#{key}" -- a key that came back from the cache as a
    # String would render "translation missing" for all four of them.
    test 'the cached stats keep their symbol keys through the cache round trip' do
      cached # cold, fills the entry
      warm = cached

      assert_equal [:schemas, :connections, :independent, :circular], warm.stats.keys
      assert_equal @live.stats, warm.stats
    end

    # ---- what the key has to separate ------------------------------------------

    # Was the graph built again, or served from the cache? Wraps the real
    # constructor rather than replacing it, so the call still returns a usable
    # graph and the assertion is about the cache, not about the stub.
    def rebuilt?(&)
      built = false
      wrapped = lambda { |**kwargs|
        built = true
        DataCycleCore::Schema::DependencyGraph.allocate.tap { |graph| graph.send(:initialize, **kwargs) }
      }

      DataCycleCore::Schema::DependencyGraph.stub(:new, wrapped, &)
      built
    end

    test 'a different locale is a different cache entry' do
      other = (I18n.available_locales - [I18n.default_locale]).first
      skip 'instance configures a single locale' if other.nil?

      cached(locale: I18n.default_locale)

      assert rebuilt? { cached(locale: other) }, 'a second locale must not be served the first one\'s entry'
      assert_not rebuilt? { cached(locale: I18n.default_locale) }, 'the first locale\'s entry must survive'
    end

    test 'different overlay_names are different cache entries' do
      overlay = @live.rows.first&.dig(:template_name)
      skip 'no rows in this instance' if overlay.nil?

      without = cached(overlay_names: [])
      with = cached(overlay_names: [overlay])

      assert_not_equal without.rows.pluck(:template_name), with.rows.pluck(:template_name)
    end

    # …and the same overlay list in another order is the SAME entry: the key sorts,
    # so two callers that assemble the list differently do not each pay for a build.
    test 'the overlay list order does not split the cache entry' do
      names = @live.rows.first(2).pluck(:template_name)
      skip 'need two rows in this instance' if names.size < 2

      cached(overlay_names: names)

      assert_not rebuilt? { cached(overlay_names: names.reverse) }, 'a reordered overlay list must hit the same entry'
    end

    # ---- invalidation ------------------------------------------------------------

    # The key carries the newest template timestamp, so a template change has to
    # produce a fresh build rather than wait out the TTL. ThingTemplate is a
    # readonly model (it is projected from the schema), so the timestamp is moved
    # the only way it can be: at the source the key reads it from.
    test 'a newer template timestamp invalidates the entry' do
      cached

      assert_not rebuilt? { cached }, 'sanity: an unchanged schema must stay cached'

      DataCycleCore::ThingTemplate.stub(:maximum, 1.hour.from_now) do
        assert rebuilt? { cached }, 'a changed template must not be served from the previous entry'
      end
    end

    # thing_counts flows into the rows but deliberately NOT into the key -- the
    # content numbers are an overview figure and may lag by up to the TTL. Pinned
    # because it is a trade-off, not an oversight: if it ever has to become exact,
    # this is the test that has to change with it.
    test 'changed thing_counts alone do not invalidate the entry' do
      first = cached(thing_counts: {})
      template = first.rows.first&.dig(:template_name)
      skip 'no rows in this instance' if template.nil?

      second = cached(thing_counts: { template => 999 })

      assert_equal 0, second.rows.first[:content_count]
      assert_equal first.rows, second.rows
    end
  end
end
