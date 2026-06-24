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

      assert_raises(StandardError) { perform_with(es, DataCycleCore::ImportJob) }
      assert es.data['last_download_import_failed']
      assert_predicate es.data['last_download_import_exception'], :present?
    end

    test 'import_job stores the provider job id after enqueue' do
      es = external_system_double(config: {})

      DataCycleCore::ExternalSystem.stub(:find, es) do
        DataCycleCore::ImportJob.perform_later(UUID)
      end

      assert es.data.key?('last_download_import_job_id')
      assert_not es.data['last_download_import_failed']
    end

    test 'import_job exposes reference id and type' do
      job = DataCycleCore::ImportJob.new(UUID, 'full')

      assert_equal UUID, job.delayed_reference_id
      assert_equal 'download_import_full', job.delayed_reference_type
      assert_predicate DataCycleCore::ImportJob, :broadcast_dashboard_jobs_now?
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
