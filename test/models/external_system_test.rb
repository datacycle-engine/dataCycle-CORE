# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DummyRefreshStrategy
    def self.process(utility_object:, options:) # rubocop:disable Lint/UnusedMethodArgument
      :refreshed
    end
  end

  class ExternalSystemTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @external_system = DataCycleCore::ExternalSystem.create!(
        name: 'Coverage External System',
        last_successful_import: 2.days.ago,
        config: {
          'download_config' => {
            'a_detail' => { 'sorting' => 2, 'source_type' => 'detail' },
            'b_main' => { 'sorting' => 1, 'source_type' => 'main' }
          },
          'import_config' => {
            'a_detail' => { 'sorting' => 2 },
            'b_main' => { 'sorting' => 1 }
          },
          'export_config' => {
            'filter' => { 'global_key' => 'global_value' },
            'my_method' => { 'filter' => { 'method_key' => 'method_value' } },
            'refresh' => { 'strategy' => 'DataCycleCore::DummyRefreshStrategy' }
          }
        },
        default_options: {
          'locales' => ['de', 'en'],
          'import' => { 'error_notification' => { 'grace_period' => 'PT0S', 'emails' => ['ops@datacycle.at'] } }
        }
      )
    end

    test 'ranked and pretty download/import lists are sorted by sorting' do
      assert_equal([[1, :b_main], [2, :a_detail]], @external_system.download_list_ranked)
      assert_equal([[1, :b_main], [2, :a_detail]], @external_system.import_list_ranked)
      assert_equal(['1   :b_main', '2   :a_detail'], @external_system.download_pretty_list)
      assert_equal(['1   :b_main', '2   :a_detail'], @external_system.import_pretty_list)
    end

    test 'export_config filter lookups fall back to the global filter' do
      assert_equal('method_value', @external_system.export_config_by_method_name_and_filter_key('my_method', 'method_key'))
      assert_equal('method_value', @external_system.export_config_by_filter_key('my_method', 'method_key'))
      assert_equal('global_value', @external_system.export_config_by_filter_key('other_method', 'global_key'))
    end

    test 'full_options merges defaults, step config and overrides' do
      options = @external_system.full_options('a_detail', 'import', { extra: true })

      assert_equal('a_detail', options.dig(:import, :name))
      assert(options[:extra])
    end

    test 'locales come from the default options' do
      assert_equal(['de', 'en'], @external_system.locales)
    end

    test 'import_queue defaults to :importers' do
      assert_equal(:importers, DataCycleCore::ExternalSystem.new(default_options: {}).import_queue)
      assert_equal(:importers, DataCycleCore::ExternalSystem.new(default_options: nil).import_queue)
    end

    test 'import_queue can be overridden via default_options' do
      assert_equal(:importers_short, DataCycleCore::ExternalSystem.new(default_options: { 'queue' => 'importers_short' }).import_queue)
    end

    test 'import_queue only reads the top-level queue, not a nested import queue' do
      assert_equal(:importers, DataCycleCore::ExternalSystem.new(default_options: { 'import' => { 'queue' => 'importers_short' } }).import_queue)
    end

    test 'import_queue falls back to :importers for a queue that is not an importer queue' do
      assert_equal(:importers, DataCycleCore::ExternalSystem.new(default_options: { 'queue' => 'importers_shrot' }).import_queue)
      assert_equal(:importers, DataCycleCore::ExternalSystem.new(default_options: { 'queue' => 'mailers' }).import_queue)
    end

    test 'find_from_hash resolves by identifier and by name' do
      assert_equal(@external_system.id, DataCycleCore::ExternalSystem.find_from_hash({ 'identifier' => @external_system.identifier })&.id)
      assert_equal(@external_system.id, DataCycleCore::ExternalSystem.find_from_hash({ 'name' => @external_system.name })&.id)
    end

    # --- process-level cache (import performance) ----------------------------
    test 'cached_by_id returns the system and nil for blank ids' do
      DataCycleCore::ExternalSystem.reset_cache!

      assert_equal(@external_system.id, DataCycleCore::ExternalSystem.cached_by_id(@external_system.id)&.id)
      assert_nil(DataCycleCore::ExternalSystem.cached_by_id(nil))
      assert_nil(DataCycleCore::ExternalSystem.cached_by_id(''))
    end

    test 'cached_by_key indexes systems by identifier and by name' do
      DataCycleCore::ExternalSystem.reset_cache!
      by_key = DataCycleCore::ExternalSystem.cached_by_key

      assert_kind_of(Hash, by_key)
      assert_equal(@external_system.id, by_key[@external_system.identifier]&.id)
      assert_equal(@external_system.id, by_key[@external_system.name]&.id)
    end

    test 'cached_index memoizes until reset' do
      DataCycleCore::ExternalSystem.reset_cache!
      first = DataCycleCore::ExternalSystem.cached_index

      assert_same(first, DataCycleCore::ExternalSystem.cached_index)

      DataCycleCore::ExternalSystem.reset_cache!

      assert_not_same(first, DataCycleCore::ExternalSystem.cached_index)
    end

    test 'reset_cache! rebuilds the index from the current systems' do
      DataCycleCore::ExternalSystem.reset_cache!

      assert_equal(DataCycleCore::ExternalSystem.unscoped.count, DataCycleCore::ExternalSystem.cached_index[:by_id].size)
    end

    # Returns the payload of the notification the call emitted, or nil if it emitted none.
    def notified_repeated_failure(type, exception)
      events = []
      subscriber = ActiveSupport::Notifications.subscribe("#{type}_failed_repeatedly.datacycle") { |*args| events << args }
      @external_system.check_for_repeated_failure(type, exception)
      events.dig(0, 4)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    test 'check_for_repeated_failure instruments a notification past the grace period' do
      assert_predicate(notified_repeated_failure('import', StandardError.new('boom')), :present?)
    end

    # This message is what the subscriber hands the mailer and error_notify.html.erb renders verbatim,
    # so it needs the same class-name prefix as the import log.
    test 'check_for_repeated_failure names the exception class in the notified message' do
      opaque = 'Translation missing: de.mongoid.errors.messages.attribute_not_loaded.message'

      notified = notified_repeated_failure('import', StandardError.new(opaque))

      assert_includes(notified[:exception].message, "StandardError: #{opaque}")
    end

    test 'check_for_repeated_failure does not name a message-less exception twice' do
      notified = notified_repeated_failure('import', ArgumentError.new)

      assert_includes(notified[:exception].message, 'The last exception was: ArgumentError')
      assert_not_includes(notified[:exception].message, 'ArgumentError: ArgumentError')
    end

    # WebhookError#initialize falls back to `self` when built without an original error, and #message
    # delegates to it — without the guard, rendering one would recurse until SystemStackError
    test 'check_for_repeated_failure survives an exception whose message delegates to itself' do
      notified = notified_repeated_failure('import', DataCycleCore::Error::WebhookError.new(nil))

      assert_includes(notified[:exception].message, 'DataCycleCore::Error::WebhookError')
    end

    test 'refresh raises without a configured strategy' do
      es = DataCycleCore::ExternalSystem.new(name: 'No Refresh', config: { 'export_config' => {} })

      assert_raises(RuntimeError) { es.refresh }
    end

    test 'refresh delegates to the configured strategy' do
      DataCycleCore::Export::PushObject.stub(:new, Object.new) do
        assert_equal(:refreshed, @external_system.refresh)
      end
    end

    test 'endpoint_module returns nil without a module base' do
      assert_nil(@external_system.endpoint_module)
    end

    test 'endpoint_module resolves the configured module base' do
      es = DataCycleCore::ExternalSystem.new(name: 'Module Base ES', module_base: 'NonExistentCoverageModule')

      assert_nil(es.endpoint_module)
    end

    test 'reset clears the import/download timestamps' do
      @external_system.reset

      assert_nil(@external_system.last_successful_import)
    end

    # --- MongoDB-backed collection helpers ------------------------------------
    test 'database_name is namespaced by id' do
      assert_equal("#{DataCycleCore::Generic::Collection.database_name}_#{@external_system.id}", @external_system.database_name)
    end

    test 'collections returns an indexed struct of mongo collections' do
      # external_system.rb intentionally returns an OpenStruct (it is itself OpenStructUse-excluded)
      assert_kind_of(OpenStruct, @external_system.collections) # rubocop:disable Style/OpenStructUse
    end

    test 'collection yields the named mongo collection' do
      count = @external_system.collection('coverage_test') { |c| c.count_documents({}) }

      assert_equal(0, count)
    end

    test 'query and query2 run within the external-system database' do
      assert_equal(0, @external_system.query('coverage_test') { DataCycleCore::Generic::Collection.count })
      assert_equal(0, @external_system.query2('coverage_test') { DataCycleCore::Generic::Collection2.count })
    end

    # Mongoid 9 dropped the legacy persistence-context behavior, so a document now remembers the
    # storage options it was created under. `query` combines a global `Mongoid.override_database`
    # with a block-local `with(collection:)` and resets the override in its `ensure`, which makes
    # "where did the write actually land" the invariant worth pinning: in this system's own database,
    # and never in the default one that every other external system shares.
    #
    # The cleanup covers both databases on purpose. `destroy_all` only reaches the namespaced one, so
    # were the write ever to land in the default database, the leftover would fail every later run of
    # this test — including runs against a since-fixed `query`.
    test 'a document written inside query lands in the external-system database only' do
      @external_system.stub(:id, 'c3') do
        purge_default_database('coverage_context', 'context-1')

        @external_system.query('coverage_context') do
          DataCycleCore::Generic::Collection.create!(external_id: 'context-1', dump: { 'de' => { 'id' => 'context-1' } })
        end

        namespaced = @external_system.query('coverage_context') { DataCycleCore::Generic::Collection.where(external_id: 'context-1').count }
        default = default_database_count('coverage_context', 'context-1')

        assert_equal(1, namespaced)
        assert_equal(0, default)
      ensure
        @external_system.destroy_all('coverage_context')
        purge_default_database('coverage_context', 'context-1')
      end
    end

    def default_database_count(collection_name, external_id)
      DataCycleCore::Generic::Collection.with(collection: collection_name) { |c| c.where(external_id:).count }
    end

    def purge_default_database(collection_name, external_id)
      DataCycleCore::Generic::Collection.with(collection: collection_name) { |c| c.where(external_id:).delete_all }
    end

    test 'maintenance copies archive and delete metadata from de to en' do
      @external_system.stub(:id, 'c2') do
        now = Time.current
        @external_system.query('coverage_maint') do
          DataCycleCore::Generic::Collection.create!(
            external_id: 'maintenance-1',
            dump: {
              'de' => {
                'deleted_at' => now, 'archived_at' => now, 'archive_reason' => 'gone',
                'last_seen_before_archived' => now, 'last_seen_before_delete' => now, 'delete_reason' => 'gone'
              },
              'en' => {}
            }
          )
        end

        @external_system.maintenance('coverage_maint')

        item = @external_system.query('coverage_maint') { DataCycleCore::Generic::Collection.first }

        assert_predicate(item.dump['en']['deleted_at'], :present?)
        assert_predicate(item.dump['en']['archive_reason'], :present?)
      ensure
        @external_system.destroy_all('coverage_maint')
      end
    end

    test 'destroy_all and maintenance run without error on empty collections' do
      # the test mongo base db name is long; a short id keeps the namespaced db
      # name under mongo's 63-char limit for the find-cursor operations.
      @external_system.stub(:id, 'c1') do
        assert_nothing_raised do
          @external_system.destroy_all('coverage_test')
          @external_system.maintenance('coverage_test')
        end
      end
    end

    # --- grouping / external URLs --------------------------------------------
    test 'grouped_by_type buckets external systems by their configured modules' do
      result = DataCycleCore::ExternalSystem.grouped_by_type

      assert(result.key?(:import))
      assert(result.key?(:export))
      assert(result.key?(:service))
      assert(result.key?(:foreign))
    end

    test 'external_url and external_detail_url format the configured templates' do
      es = DataCycleCore::ExternalSystem.new(
        name: 'URL ES',
        default_options: {
          'external_url' => 'https://ext.test/%<locale>s/%<external_key>s',
          'external_detail_url' => 'https://ext.test/detail/%<external_key>s'
        }
      )
      content = struct_double(external_key: 'abc123')

      assert_equal("https://ext.test/#{I18n.locale}/abc123", es.external_url(content))
      assert_equal('https://ext.test/detail/abc123', es.external_detail_url(content))
      assert_nil(es.external_url(struct_double(external_key: nil)))
      assert_nil(DataCycleCore::ExternalSystem.new(name: 'No URL').external_detail_url(content))
    end

    # --- step orchestration -----------------------------------------------------
    test 'sorted_step_config_by_type and sorted_step_configs expand and merge step configs' do
      download_steps = @external_system.sorted_step_config_by_type(:download)

      assert_equal(['b_main', 'a_detail'], download_steps.pluck('name'))
      assert_equal([:download, :download], download_steps.pluck('type'))

      all_steps = @external_system.sorted_step_configs

      assert_equal(['b_main', 'a_detail', 'b_main', 'a_detail'], all_steps.pluck('name'))
    end

    test 'relevant_steps_for filters by source_type and source_steps_successful? checks timestamps' do
      assert_equal(['b_main'], @external_system.relevant_steps_for('main').pluck('name'))
      assert_not @external_system.source_steps_successful?('main', :download)
    end

    test 'download_range runs the download steps within the sorting range' do
      @external_system.stub(:broadcast_update, nil) do
        @external_system.stub(:download_single, true) do
          assert @external_system.download_range({ min: 0, max: 10 })
        end
      end
    end

    test 'timestamp_key_for_step resolves config from download or import without an explicit type' do
      assert_equal('d_b_main', @external_system.timestamp_key_for_step('b_main'))
    end

    test 'type_and_name_for_step_key parses prefixed step keys' do
      assert_equal([:download, 'b_main'], @external_system.type_and_name_for_step_key('d_b_main'))
      assert_equal([:import, 'a_detail'], @external_system.type_and_name_for_step_key('i_a_detail'))
      assert_nil(@external_system.type_and_name_for_step_key('invalid-key'))
    end

    test 'import_range runs the import steps within the sorting range' do
      @external_system.stub(:broadcast_update, nil) do
        @external_system.stub(:import_single, true) do
          assert_nothing_raised { @external_system.import_range({ min: 0, max: 10 }) }
        end
      end
    end

    test 'add_credentials_for_step! resolves the credentials index by key' do
      @external_system.stub(:credentials, [{ 'credential_key' => 'k1', 'token' => 'secret' }]) do
        options = { credential_key: 'k1' }
        @external_system.add_credentials_for_step!(options)

        assert_equal(0, options[:credentials_index])
        assert_equal([{ 'credential_key' => 'k1', 'token' => 'secret' }], options[:credentials])
      end
    end

    test 'add_credentials_for_step! raises when the credential key is unknown' do
      @external_system.stub(:credentials, [{ 'credential_key' => 'k1' }]) do
        assert_raises(RuntimeError) { @external_system.add_credentials_for_step!({ credential_key: 'missing' }) }
      end
    end

    test 'import_one merges the external key into a source filter and imports' do
      captured = nil

      @external_system.stub(:import_single, lambda { |name, options|
        captured = [name, options]
        true
      }) do
        assert @external_system.import_one('b_main', 'ext-123')
      end

      assert_equal('b_main', captured[0])
      assert_equal({ external_id: 'ext-123' }, captured[1].dig(:import, :source_filter))
    end

    # An external system without any step info has only the last/last_successful pair to go by, where
    # a first run that is still going is indistinguishable from a failed one. Without the queue lookup
    # such a system reads as 'error' while it is importing.
    def claim_import_job(system, klass)
      job = klass.new(system.id)
      row = SolidQueue::Job.create!(queue_name: 'importers', class_name: klass.name, arguments: job.serialize, concurrency_key: job.concurrency_key)
      process = SolidQueue::Process.create!(kind: 'Worker', name: "test-worker-#{row.id}", pid: 1, last_heartbeat_at: Time.current)
      SolidQueue::ClaimedExecution.create!(job: row, process:)
    end

    test 'a system with no step info reads as running while its import job is claimed' do
      system = DataCycleCore::ExternalSystem.create!(name: 'Legacy Status System', last_import: 1.minute.ago)

      assert_equal 'error', system.last_import_status

      claim_import_job(system, DataCycleCore::ImportOnlyJob)

      assert_equal 'running', DataCycleCore::ExternalSystem.find(system.id).last_import_status
    end

    test 'a claimed download job does not make the import read as running' do
      system = DataCycleCore::ExternalSystem.create!(name: 'Legacy Download System', last_download: 1.minute.ago, last_import: 1.minute.ago)

      claim_import_job(system, DataCycleCore::DownloadJob)
      system = DataCycleCore::ExternalSystem.find(system.id)

      assert_equal 'running', system.last_download_status
      assert_equal 'error', system.last_import_status
    end
  end
end
