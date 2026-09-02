# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SolidQueueJobExtensionTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def create_job(**attributes)
      job = DataCycleCore::AutoTranslationJob.new(SecureRandom.uuid, 'de')

      SolidQueue::Job.create!(
        queue_name: 'default',
        class_name: job.class.name,
        arguments: job.serialize,
        concurrency_key: job.concurrency_key,
        **attributes
      )
    end

    test 'live includes a job that is still waiting to run' do
      job = create_job

      assert_includes SolidQueue::Job.live, job
    end

    test 'live excludes a finished job' do
      job = create_job(finished_at: Time.current)

      assert_not_includes SolidQueue::Job.live, job
    end

    # with preserve_finished_jobs = false a failed execution is the only thing that keeps a row
    # around, so this is the case that matters: without the filter such a row is indistinguishable
    # from a job that is about to run
    test 'live excludes a permanently failed job' do
      job = create_job
      job.failed_with(StandardError.new('boom'))

      assert_not_includes SolidQueue::Job.live, job
    end
  end
end
