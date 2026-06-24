# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class JobExtensionsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    def with_persisted_jobs
      previous = Delayed::Worker.delay_jobs
      Delayed::Worker.delay_jobs = true
      yield
    ensure
      Delayed::Worker.delay_jobs = previous
    end

    test 'find_by_identifiers deserializes a queued job and destroy removes it' do
      with_persisted_jobs { DataCycleCore::AutoTranslationJob.perform_later(UUID, 'de') }

      job = DataCycleCore::AutoTranslationJob.find_by_identifiers(
        reference_id: UUID,
        reference_type: 'AutoTranslationJob',
        queue_name: 'default'
      )

      assert_equal UUID, job.arguments[0]
      assert_predicate job.provider_job_id, :present?

      job.destroy

      assert_nil DataCycleCore::AutoTranslationJob.find_by_identifiers(
        reference_id: UUID,
        reference_type: 'AutoTranslationJob',
        queue_name: 'default'
      )
    end

    test 'find_by_identifiers returns nil when nothing matches' do
      assert_nil DataCycleCore::AutoTranslationJob.find_by_identifiers(
        reference_id: 'missing',
        reference_type: 'AutoTranslationJob',
        queue_name: 'default'
      )
    end

    test 'a failing enqueued job is retried instead of raising' do
      job = DataCycleCore::ComputePropertiesJob.new(UUID, ['slug'])
      job.enqueued_at = Time.now.utc.iso8601

      with_persisted_jobs do
        DataCycleCore::Thing.stub(:find, ->(*) { raise StandardError, 'boom' }) do
          assert_nothing_raised { job.perform_now }
        end
      end
    end

    test 'reference id and type resolve procs lazily' do
      obj = Object.new
      obj.define_singleton_method(:id) { 'rid' }
      job = DataCycleCore::WatchListSubscriberNotificationJob.new(obj, nil, [], 'changed')

      assert_equal 'rid', job.reference_id
      assert_equal 'watch_list_subscriber_notification_job-changed', job.reference_type
    end
  end
end
