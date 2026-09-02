# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImportJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    def external_system_double(config: {}, raise_on: nil)
      data = nil
      calls = []
      es = Object.new
      es.define_singleton_method(:config) { config }
      es.define_singleton_method(:data) { data }
      es.define_singleton_method(:data=) { |value| data = value }
      es.define_singleton_method(:save) { true }
      es.define_singleton_method(:save!) { true }
      es.define_singleton_method(:calls) { calls }
      [:download, :import, :download_single, :import_single].each do |method_name|
        es.define_singleton_method(method_name) do |*args|
          raise StandardError, 'boom' if raise_on == method_name

          calls << [method_name, *args]
          true
        end
      end
      es
    end

    def perform_with(es, klass, *args)
      DataCycleCore::ExternalSystem.stub(:find, es) do
        klass.perform_now(UUID, *args)
      end
    end

    test 'import_job downloads and imports when a download config exists' do
      es = external_system_double(config: { 'download_config' => {} })

      perform_with(es, DataCycleCore::ImportJob)

      assert_includes es.calls, [:download, {}]
      assert_includes es.calls, [:import, {}]
    end

    test 'import_job only imports when there is no download config' do
      es = external_system_double(config: {})

      perform_with(es, DataCycleCore::ImportJob, 'full')

      assert_equal [[:import, { mode: 'full' }]], es.calls
    end

    test 'import_job records the failure and re-raises on error' do
      es = external_system_double(config: { 'download_config' => {} }, raise_on: :download)

      # the perform method records the failure and re-raises; retry/backoff on top of that is
      # ActiveJob's (retry_on) concern, so exercise perform directly rather than perform_now.
      assert_raises(StandardError) do
        DataCycleCore::ExternalSystem.stub(:find, es) do
          DataCycleCore::ImportJob.new(UUID).perform(UUID)
        end
      end
      assert es.data['last_download_import_failed']
      assert_predicate es.data['last_download_import_exception'], :present?
    end

    test 'import_job stores the provider job id after enqueue' do
      es = external_system_double(config: {})

      DataCycleCore::ExternalSystem.stub(:find, es) do
        perform_enqueued_jobs do
          DataCycleCore::ImportJob.perform_later(UUID)
        end
      end

      assert es.data.key?('last_download_import_job_id')
      assert_not es.data['last_download_import_failed']
    end

    test 'import_job exposes its concurrency key' do
      job = DataCycleCore::ImportJob.new(UUID, 'full')

      assert_equal "importers/#{UUID}", job.concurrency_key
    end

    test 'import_job is enqueued on the importers queue by default' do
      es = external_system_double
      es.define_singleton_method(:import_queue) { :importers }

      DataCycleCore::ExternalSystem.stub(:find_by, es) do
        assert_equal 'importers', DataCycleCore::ImportJob.new(UUID).queue_name
      end
    end

    test 'import_job honours the queue configured on the external system' do
      es = external_system_double
      es.define_singleton_method(:import_queue) { :importers_short }

      DataCycleCore::ExternalSystem.stub(:find_by, es) do
        assert_equal 'importers_short', DataCycleCore::ImportJob.new(UUID).queue_name
      end
    end

    test 'import_job falls back to the importers queue when the system is missing' do
      DataCycleCore::ExternalSystem.stub(:find_by, nil) do
        assert_equal 'importers', DataCycleCore::ImportJob.new(UUID).queue_name
      end
    end

    test 'download_job downloads via the block' do
      es = external_system_double
      perform_with(es, DataCycleCore::DownloadJob)

      assert_equal [[:download, {}]], es.calls
    end

    test 'download_full_job downloads in full mode' do
      es = external_system_double
      perform_with(es, DataCycleCore::DownloadFullJob)

      assert_equal [[:download, { mode: 'full' }]], es.calls
    end

    test 'download_partial_job downloads a single endpoint' do
      es = external_system_double
      perform_with(es, DataCycleCore::DownloadPartialJob, 'places', 'full')

      assert_equal [[:download_single, 'places', { mode: 'full' }]], es.calls
    end

    test 'import_full_job imports in full mode' do
      es = external_system_double
      perform_with(es, DataCycleCore::ImportFullJob)

      assert_equal [[:import, { mode: 'full' }]], es.calls
    end

    test 'import_only_job imports without downloading' do
      es = external_system_double
      perform_with(es, DataCycleCore::ImportOnlyJob, 'full')

      assert_equal [[:import, { mode: 'full' }]], es.calls
    end

    test 'import_partial_job imports a single endpoint' do
      es = external_system_double
      perform_with(es, DataCycleCore::ImportPartialJob, 'places')

      assert_equal [[:import_single, 'places', {}]], es.calls
    end
  end
end
