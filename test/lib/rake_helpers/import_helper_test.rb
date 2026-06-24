# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'
require 'rake_helpers/import_helper'

module DataCycleCore
  class ImportHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ExternalSourceStub = Struct.new(:id)

    test 'external_system returns the system when download and import configs exist' do
      external_source = ImportHelper.external_system('base-system')

      assert_equal 'base-system', external_source.identifier
    end

    test 'external_system raises when the source cannot be found' do
      DataCycleCore::ExternalSystem.stub(:by_names_identifiers_or_ids, nil) do
        error = assert_raises(RuntimeError) { ImportHelper.external_system('does-not-exist') }
        assert_includes error.message, 'External source not found'
      end
    end

    test 'external_system raises when the source is ambiguous' do
      ambiguous = Object.new
      def ambiguous.nil? = false
      def ambiguous.many? = true

      DataCycleCore::ExternalSystem.stub(:by_names_identifiers_or_ids, ambiguous) do
        error = assert_raises(RuntimeError) { ImportHelper.external_system('base') }
        assert_includes error.message, 'Ambiguous external source'
      end
    end

    test 'external_system raises when the import config is missing' do
      error = assert_raises(RuntimeError) { ImportHelper.external_system('local-system') }
      assert_includes error.message, 'No import config found'
    end

    test 'external_system raises when the download config is missing' do
      error = assert_raises(RuntimeError) { ImportHelper.external_system('local-system', ['download']) }
      assert_includes error.message, 'No download config found'
    end

    test 'convert_args_to_options casts count arguments to integers' do
      options = ImportHelper.convert_args_to_options({ max_count: '5', min_count: '2', external_source_id: 'base-system' })

      assert_equal 5, options[:max_count]
      assert_equal 2, options[:min_count]
      assert_equal 'base-system', options[:external_source_id]
    end

    test 'perform_job runs the job immediately when run_now is truthy' do
      job = Minitest::Mock.new
      job.expect(:queue_name, 'queue')
      job.expect(:delayed_reference_type, 'type')
      job.expect(:delayed_reference_id, 1)
      job.expect(:perform_now, nil)

      job_class = Class.new
      job_class.define_singleton_method(:new) { |*| job }

      Delayed::Job.stub(:exists?, false) do
        ImportHelper.perform_job(ExternalSourceStub.new(1), 'mode', 'true', job_class)
      end

      assert_mock job
    end

    test 'perform_job enqueues the job when run_now is falsy' do
      job = Minitest::Mock.new
      job.expect(:queue_name, 'queue')
      job.expect(:delayed_reference_type, 'type')
      job.expect(:delayed_reference_id, 1)
      job.expect(:enqueue, nil)

      job_class = Class.new
      job_class.define_singleton_method(:new) { |*| job }

      Delayed::Job.stub(:exists?, false) do
        ImportHelper.perform_job(ExternalSourceStub.new(1), 'mode', false, job_class)
      end

      assert_mock job
    end

    test 'perform_job does nothing when an equivalent job is already queued' do
      job = Minitest::Mock.new
      job.expect(:queue_name, 'queue')
      job.expect(:delayed_reference_type, 'type')
      job.expect(:delayed_reference_id, 1)

      job_class = Class.new
      job_class.define_singleton_method(:new) { |*| job }

      Delayed::Job.stub(:exists?, true) do
        ImportHelper.perform_job(ExternalSourceStub.new(1), 'mode', true, job_class)
      end

      assert_mock job
    end

    test 'legacy_task invokes and reenables the matching rake task' do
      task = Minitest::Mock.new
      task.expect(:invoke, nil, [])
      task.expect(:reenable, nil)

      Rake::Task.stub(:[], lambda { |name|
        assert_equal 'data_cycle_core:import:foo', name
        task
      }) do
        ImportHelper.legacy_task('foo')
      end

      assert_mock task
    end

    test 'import_by_cred requires a credential key' do
      error = assert_raises(RuntimeError) { ImportHelper.import_by_cred({}) }
      assert_includes error.message, 'credential_key is required'
    end

    test 'import_by_cred imports every configured import when no names are given' do
      imported = []
      external_source = Object.new
      external_source.define_singleton_method(:config) { { 'import_config' => { 'images' => { 'sorting' => 2 }, 'places' => { 'sorting' => 1 } } } }
      external_source.define_singleton_method(:import_single) { |name, _options| imported << name }

      DataCycleCore::ExternalSystem.stub(:by_names_identifiers_or_ids, [external_source]) do
        ImportHelper.import_by_cred({ credential_key: 'key', external_source_id: 'base-system' })
      end

      assert_equal [:places, :images], imported
    end

    test 'import_by_cred imports the explicitly requested names' do
      imported = []
      external_source = Object.new
      external_source.define_singleton_method(:config) { { 'import_config' => {} } }
      external_source.define_singleton_method(:import_single) { |name, _options| imported << name }

      DataCycleCore::ExternalSystem.stub(:by_names_identifiers_or_ids, [external_source]) do
        ImportHelper.import_by_cred({ credential_key: 'key', external_source_id: 'base-system', import_names: 'places' })
      end

      assert_equal [:places], imported
    end

    test 'download_by_cred requires a credential key' do
      error = assert_raises(RuntimeError) { ImportHelper.download_by_cred({}) }
      assert_includes error.message, 'credential_key is required'
    end

    test 'download_by_cred raises when the external source is missing' do
      DataCycleCore::ExternalSystem.stub(:by_names_identifiers_or_ids, []) do
        error = assert_raises(RuntimeError) { ImportHelper.download_by_cred({ credential_key: 'key', external_source_id: 'missing' }) }
        assert_includes error.message, 'External source not found'
      end
    end

    test 'download_by_cred downloads the requested names' do
      downloaded = []
      external_source = Object.new
      external_source.define_singleton_method(:download_single) { |name, _options| downloaded << name }

      DataCycleCore::ExternalSystem.stub(:by_names_identifiers_or_ids, [external_source]) do
        ImportHelper.download_by_cred({ credential_key: 'key', external_source_id: 'base-system', download_names: 'images|places' })
      end

      assert_equal [:images, :places], downloaded
    end

    test 'download_by_cred downloads everything when no names are given' do
      called_with = nil
      external_source = Object.new
      external_source.define_singleton_method(:download) { |options| called_with = options }

      DataCycleCore::ExternalSystem.stub(:by_names_identifiers_or_ids, [external_source]) do
        ImportHelper.download_by_cred({ credential_key: 'key', external_source_id: 'base-system' })
      end

      assert called_with[:skip_save]
    end
  end
end
