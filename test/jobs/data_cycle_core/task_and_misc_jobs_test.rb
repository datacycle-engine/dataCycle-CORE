# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  class TaskAndMiscJobsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    def stub_rake(task_name, args, &block)
      task = Minitest::Mock.new
      task.expect(:reenable, nil)
      task.expect(:invoke, nil, args)

      Rails.application.stub(:load_tasks, nil) do
        Rake::Task.stub(:[], lambda { |name|
          assert_equal task_name, name
          task
        }, &block)
      end

      assert_mock task
    end

    test 'run_task_job loads, reenables and invokes the rake task' do
      stub_rake('my:task', ['arg']) do
        DataCycleCore::RunTaskJob.perform_now('my:task', ['arg'])
      end
    end

    test 'run_task_job builds its concurrency key from task and arguments' do
      job = DataCycleCore::RunTaskJob.new('my:task', ['a', 'b'])

      assert_equal 'DataCycleCore::RunTaskJob/my:task/a_b', job.concurrency_key
      assert_equal 0, job.priority
    end

    test 'run_task_job keys the same task with different arguments separately' do
      assert_not_equal DataCycleCore::RunTaskJob.new('my:task', ['a']).concurrency_key,
                       DataCycleCore::RunTaskJob.new('my:task', ['b']).concurrency_key
    end

    # :discard leaves no blocked execution behind, so the uniqueness guard has to look at the jobs
    # table; a blocked-execution-only check would report no duplicate and let this one through
    test 'run_task_job discards a duplicate instead of queueing it behind the original' do
      assert_equal 'discard', DataCycleCore::RunTaskJob.concurrency_on_conflict.to_s

      job = DataCycleCore::RunTaskJob.new('my:task', ['a'])
      create_queue_row(job)

      assert_empty SolidQueue::BlockedExecution.where(concurrency_key: job.concurrency_key)
      assert_not DataCycleCore::RunTaskJob.perform_later('my:task', ['a'])
      assert DataCycleCore::RunTaskJob.perform_later('my:task', ['b'])
    end

    # The counterpart for the default :block mode, which is what all but three UniqueApplicationJob
    # subclasses use. CheckForDuplicatesJob stands in for the whole set: what is under test is
    # UniqueApplicationJob's before_enqueue, not anything specific to that job.
    test 'a blocking unique job keeps one waiting duplicate and drops the next' do
      assert_equal 'block', DataCycleCore::CheckForDuplicatesJob.concurrency_on_conflict.to_s

      job = DataCycleCore::CheckForDuplicatesJob.new(UUID)
      running = create_queue_row(job)

      # the waiting slot is still free, and what goes into it is what carries the newest state
      assert_predicate running, :ready?
      assert_enqueued_jobs 1, only: DataCycleCore::CheckForDuplicatesJob do
        assert DataCycleCore::CheckForDuplicatesJob.perform_later(UUID)
      end

      waiting = create_queue_row(job)

      assert SolidQueue::BlockedExecution.exists?(job_id: waiting.id)
      assert_no_enqueued_jobs only: DataCycleCore::CheckForDuplicatesJob do
        assert_not DataCycleCore::CheckForDuplicatesJob.perform_later(UUID)
      end

      # a different key is unaffected — the guard drops duplicates, not the job class
      assert_enqueued_jobs 1, only: DataCycleCore::CheckForDuplicatesJob do
        assert DataCycleCore::CheckForDuplicatesJob.perform_later(SecureRandom.uuid)
      end
    end

    test 'a UniqueApplicationJob without limits_concurrency has nothing to be unique by' do
      klass = Class.new(DataCycleCore::UniqueApplicationJob) do
        def self.name = 'KeylessUniqueJob'
      end

      assert_raises(RuntimeError) { klass.new.abort_if_queued }
    end

    test 'run_task_job_import clears, loads and invokes the rake task' do
      stub_rake('importer:task', []) do
        DataCycleCore::RunTaskJobImport.perform_now('importer:task')
      end
    end

    test 'run_task_job_import builds its concurrency key' do
      job = DataCycleCore::RunTaskJobImport.new('importer:task')

      assert_equal 'DataCycleCore::RunTaskJobImport/importer:task', job.concurrency_key
      assert_equal 5, job.priority
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
    end

    test 'rebuild_classification_mappings exposes its concurrency key and priority' do
      job = DataCycleCore::RebuildClassificationMappingsJob.new

      assert_equal 'DataCycleCore::RebuildClassificationMappingsJob/rebuild_transitive_tables', job.concurrency_key
      assert_equal 0, job.priority
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
