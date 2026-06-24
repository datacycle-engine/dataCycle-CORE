# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  class TaskAndMiscJobsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    def stub_rake(task_name, args, &block)
      task = Minitest::Mock.new
      task.expect(:invoke, nil, args)

      Rake::Task.stub(:clear, nil) do
        Rails.application.stub(:load_tasks, nil) do
          Rake::Task.stub(:[], lambda { |name|
            assert_equal task_name, name
            task
          }, &block)
        end
      end

      assert_mock task
    end

    test 'run_task_job clears, loads and invokes the rake task' do
      stub_rake('my:task', ['arg']) do
        DataCycleCore::RunTaskJob.perform_now('my:task', ['arg'])
      end
    end

    test 'run_task_job builds reference id and type' do
      job = DataCycleCore::RunTaskJob.new('my:task', ['a', 'b'])

      assert_equal 'args:a_b', job.delayed_reference_id
      assert_equal 'RunTaskJob: my:task', job.delayed_reference_type
      assert_equal DataCycleCore::RunTaskJob::PRIORITY, job.priority
    end

    test 'run_task_job_import clears, loads and invokes the rake task' do
      stub_rake('importer:task', []) do
        DataCycleCore::RunTaskJobImport.perform_now('importer:task')
      end
    end

    test 'run_task_job_import builds the reference id' do
      job = DataCycleCore::RunTaskJobImport.new('importer:task')

      assert_equal 'importer:task', job.delayed_reference_id
      assert_equal DataCycleCore::RunTaskJobImport::PRIORITY, job.priority
    end

    test 'unique_application_job raises for an unimplemented reference id' do
      assert_raises(RuntimeError) { DataCycleCore::UniqueApplicationJob.new.delayed_reference_id }
    end

    test 'unique_application_job clears previous jobs and reuses their schedule' do
      job = DataCycleCore::AutoTranslationJob.new(UUID, 'de')
      previous = Object.new
      run_at = 1.hour.ago
      previous.define_singleton_method(:run_at) { run_at }

      deleted = []
      relation = Object.new
      relation.define_singleton_method(:order) { |*| relation }
      relation.define_singleton_method(:first) { previous }
      relation.define_singleton_method(:delete_all) { deleted << :deleted }

      Delayed::Job.stub(:where, relation) do
        job.clear_previous_jobs
      end

      assert_equal run_at, job.scheduled_at
      assert_equal [:deleted], deleted
    end

    test 'unique_application_job keeps schedule when there is no previous job' do
      job = DataCycleCore::AutoTranslationJob.new(UUID, 'de')
      relation = Object.new
      relation.define_singleton_method(:order) { |*| relation }
      relation.define_singleton_method(:first) { nil }

      Delayed::Job.stub(:where, relation) do
        assert_nil job.clear_previous_jobs
      end
    end

    test 'rebuild_classification_mappings rebuilds tables and broadcasts the button state' do
      states = []
      DataCycleCore::TurboService.stub(:broadcast_localized_replace_to, ->(*_args, **kwargs) { states << kwargs.dig(:locals, :rebuilding) }) do
        DataCycleCore::Feature::TransitiveClassificationPath.stub(:rebuild_transitive_tables!, nil) do
          DataCycleCore::RebuildClassificationMappingsJob.perform_now
        end
      end

      assert_includes states, true
      assert_includes states, false
      assert_predicate DataCycleCore::RebuildClassificationMappingsJob, :broadcast_dashboard_jobs_now?
    end

    test 'rebuild_classification_mappings exposes its reference id and priority' do
      job = DataCycleCore::RebuildClassificationMappingsJob.new

      assert_equal 'DataCycleCore::Feature::TransitiveClassificationPath#rebuild_transitive_tables!', job.delayed_reference_id
      assert_equal DataCycleCore::RebuildClassificationMappingsJob::PRIORITY, job.priority
    end

    test 'remove_content_references uses the non-translatable branch' do
      removed = []
      stored = []
      thing = Object.new
      thing.define_singleton_method(:text_with_linked_property_names) { ['description'] }
      thing.define_singleton_method(:translatable_property_names) { [] }
      thing.define_singleton_method(:first_available_locale) { 'de' }
      thing.define_singleton_method(:remove_id_from_text_props) { |linked_id:, **| removed << linked_id }
      thing.define_singleton_method(:set_data_hash) { |data_hash:| stored << data_hash }

      relation = Object.new
      relation.define_singleton_method(:find_each) { |&block| block.call(thing) }

      DataCycleCore::Thing.stub(:where, relation) do
        DataCycleCore::RemoveContentReferencesFromTextJob.perform_now(UUID, [UUID])
      end

      assert_equal [UUID], removed
      assert_equal [{}], stored
    end
  end
end
