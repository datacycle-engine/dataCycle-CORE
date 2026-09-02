# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the import-performance template caching: the process-level ThingTemplate cache,
  # the cache-backed Content#thing_template association, the explicit-join scopes it enables (Rails 8
  # no longer promotes includes() to a JOIN from a string reference), and the dev reload hook that
  # keeps the cache fresh after a template import.
  class ThingTemplateCachingTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Caching Test Artikel' })
    end

    def setup
      DataCycleCore::ThingTemplate.reset_template_caches!
    end

    # --- ThingTemplate.cached_by_template_name ------------------------------

    test 'cached_by_template_name returns the matching template' do
      cached = DataCycleCore::ThingTemplate.cached_by_template_name('Artikel')

      assert_kind_of(DataCycleCore::ThingTemplate, cached)
      assert_equal('Artikel', cached.template_name)
      assert_equal(DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel').id, cached.id)
    end

    test 'cached_by_template_name memoizes the same instance across calls' do
      first = DataCycleCore::ThingTemplate.cached_by_template_name('Artikel')

      assert_same(first, DataCycleCore::ThingTemplate.cached_by_template_name('Artikel'))
    end

    test 'cached_by_template_name returns nil for blank names' do
      assert_nil(DataCycleCore::ThingTemplate.cached_by_template_name(nil))
      assert_nil(DataCycleCore::ThingTemplate.cached_by_template_name(''))
    end

    test 'cached_by_template_name does not cache misses' do
      # controllers pass raw user input as template_name into Thing.new, so caching unknown names
      # would let arbitrary input grow the process cache unbounded — misses must re-query instead.
      assert_nil(DataCycleCore::ThingTemplate.cached_by_template_name('NonexistentTemplate'))

      cache = DataCycleCore::ThingTemplate.instance_variable_get(:@template_name_cache)

      assert_not(cache.key?('NonexistentTemplate'), 'unknown template_name must not be added to the cache')
    end

    test 'reset_template_caches! forces a fresh lookup' do
      first = DataCycleCore::ThingTemplate.cached_by_template_name('Artikel')
      DataCycleCore::ThingTemplate.reset_template_caches!
      second = DataCycleCore::ThingTemplate.cached_by_template_name('Artikel')

      assert_not_same(first, second)
      assert_equal(first.id, second.id)
    end

    # --- ThingTemplate.cached_schema_scan -----------------------------------

    test 'cached_schema_scan runs the scan once while the templates are unchanged' do
      scans = 0
      2.times { DataCycleCore::ThingTemplate.cached_schema_scan(:test_scan) { scans += 1 } }

      assert_equal(1, scans)
    end

    # the scan is invalidated by the process being replaced -- a deploy, or the importer's file touch
    # feeding the dev watcher -- never by a query, so callers asking per save cost nothing
    test 'cached_schema_scan never queries the templates to check for changes' do
      queries = count_thing_template_queries do
        3.times { DataCycleCore::ThingTemplate.cached_schema_scan(:test_scan) { :scanned } }
      end

      assert_equal(0, queries)
    end

    test 'reset_template_caches! forces a fresh schema scan' do
      assert_equal(:before, DataCycleCore::ThingTemplate.cached_schema_scan(:test_scan) { :before })

      DataCycleCore::ThingTemplate.reset_template_caches!

      assert_equal(:after, DataCycleCore::ThingTemplate.cached_schema_scan(:test_scan) { :after })
    end

    # --- Content#thing_template (cache-backed association) ------------------

    test 'thing_template is served from the cache without a preload' do
      content = DataCycleCore::Thing.find(@content.id)

      assert_not(content.association(:thing_template).loaded?, 'expected default_scope not to eager-load the template')

      template = content.thing_template

      assert_equal('Artikel', template.template_name)
      assert_same(DataCycleCore::ThingTemplate.cached_by_template_name('Artikel'), template)
    end

    test 'thing_template respects an already-loaded (preloaded) association' do
      content = DataCycleCore::Thing.where(id: @content.id).eager_load(:thing_template).first
      preloaded = content.association(:thing_template).target

      assert_predicate(content.association(:thing_template), :loaded?)
      # the eager-loaded record wins; the cache must not overwrite it
      assert_same(preloaded, content.thing_template)
    end

    # --- default_scope no longer preloads -----------------------------------

    test 'plain Thing queries do not eager-load thing_template' do
      content = DataCycleCore::Thing.where(id: @content.id).first

      assert_not(content.association(:thing_template).loaded?)
    end

    # --- Rails-8 explicit-join scopes execute -------------------------------

    test 'with_schema_type builds an executable query with an explicit join' do
      relation = DataCycleCore::Thing.with_schema_type('schema:Article')

      assert_kind_of(ActiveRecord::Relation, relation)
      assert_nothing_raised { relation.limit(1).to_a }
    end

    test 'with_default_data_type builds an executable query with an explicit join' do
      relation = DataCycleCore::Thing.with_default_data_type(['Artikel'])

      assert_kind_of(ActiveRecord::Relation, relation)
      assert_nothing_raised { relation.limit(1).to_a }
    end

    # --- dev reload hook ----------------------------------------------------

    test 'trigger_code_reload! touches thing_template.rb to force a dev-server reload' do
      importer = DataCycleCore::MasterData::Templates::TemplateImporter.allocate
      touched = nil

      FileUtils.stub(:touch, ->(path) { touched = path }) do
        importer.send(:trigger_code_reload!)
      end

      assert_equal(
        DataCycleCore::Engine.root.join('app', 'models', 'data_cycle_core', 'thing_template.rb').to_s,
        touched.to_s
      )
    end

    private

    def count_thing_template_queries
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
        count += 1 if payload[:sql].to_s.include?('thing_templates')
      end

      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
