# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for DataCycleCore::StatsJobQueue (read-only flag, runnable_types and
  # the importer job_list aggregation over Delayed::Job rows).
  class StatsJobQueueCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'StatsJobQueue is read-only and exposes runnable types' do
      assert_predicate(DataCycleCore::StatsJobQueue.new, :readonly?)
      assert_equal([], DataCycleCore::StatsJobQueue.new.runnable_types)
    end

    test 'job_list aggregates queued and running importer jobs' do
      Delayed::Job.create!(
        queue: 'importers', delayed_reference_id: SecureRandom.uuid,
        delayed_reference_type: 'DataCycleCore::ExternalSystem',
        handler: "--- {}\n", locked_at: nil, locked_by: nil
      )
      Delayed::Job.create!(
        queue: 'importers', delayed_reference_id: SecureRandom.uuid,
        delayed_reference_type: 'DataCycleCore::ExternalSystem',
        handler: "--- {}\n", locked_at: Time.zone.now, locked_by: 'worker-1'
      )

      job_list = DataCycleCore::StatsJobQueue.new.job_list

      assert_equal(2, job_list[:importers].size)
      assert_includes(job_list[:importers].pluck('status'), 'queued')
      assert_includes(job_list[:importers].pluck('status'), 'running')
    end
  end
end
