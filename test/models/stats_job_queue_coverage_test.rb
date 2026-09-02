# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for DataCycleCore::StatsJobQueue (read-only flag, runnable_types and
  # the importer job_list aggregation over SolidQueue::Job rows).
  class StatsJobQueueCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'StatsJobQueue is read-only and exposes runnable types' do
      assert_predicate(DataCycleCore::StatsJobQueue.new, :readonly?)
      assert_equal([], DataCycleCore::StatsJobQueue.new.runnable_types)
    end

    test 'job_list aggregates queued and running importer jobs' do
      # a claimed importer job (reported as running) ...
      enqueue_importer_job
      process = SolidQueue::Process.create!(kind: 'Worker', pid: 1, name: 'test-worker', hostname: 'test', last_heartbeat_at: Time.current)
      SolidQueue::ReadyExecution.claim('importers', 10, process.id)
      # ... and a still-ready importer job (reported as queued)
      enqueue_importer_job

      job_list = DataCycleCore::StatsJobQueue.new.job_list

      assert_equal(2, job_list[:importers].size)
      assert_includes(job_list[:importers].pluck('status'), 'queued')
      assert_includes(job_list[:importers].pluck('status'), 'running')
    end

    test 'job_list includes jobs from the importers_short queue' do
      enqueue_importer_job('importers_short')

      job_list = DataCycleCore::StatsJobQueue.new.job_list

      assert_equal(1, job_list[:importers].size)
    end

    private

    # A persisted SolidQueue job in the importers queue whose first argument is a valid
    # external_system UUID (StatsJobQueue only aggregates those).
    def enqueue_importer_job(queue_name = 'importers')
      active_job = DataCycleCore::ImportJob.new(SecureRandom.uuid)
      SolidQueue::Job.create!(
        queue_name:,
        class_name: active_job.class.name,
        arguments: active_job.serialize,
        concurrency_key: active_job.concurrency_key
      )
    end
  end
end
