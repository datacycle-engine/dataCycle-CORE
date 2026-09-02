# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module JobExtensions
    class CallbacksTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # A job that fails on demand and records which callbacks ran for it.
      class TestJob < DataCycleCore::ApplicationJob
        queue_as :default
        limits_concurrency key: ->(*args) { args[0] }

        cattr_accessor :events, default: []
        cattr_accessor :raise_with

        after_success { events << [:success, last_error_level] }
        after_error { events << [:error, last_error_level] }
        after_failure { events << [:failure, last_error_level] }

        def perform(_key)
          events << [:performed, nil]

          raise raise_with if raise_with
        end
      end

      # WebhookJob does this to keep a synchronous export from blowing up in the caller's face
      class SwallowingJob < TestJob
        def discard_on_failure?
          true
        end
      end

      # a callback a subclass adds is registered after the around_perform and therefore runs inside it
      class FailingCallbackJob < TestJob
        before_perform { raise 'callback boom' }
      end

      class TestError < StandardError; end

      # discard_on also takes the class name, for an exception whose gem may not be loaded yet
      class StringDiscardJob < TestJob
        discard_on 'DataCycleCore::JobExtensions::CallbacksTest::TestError'
      end

      class UnresolvableDiscardJob < TestJob
        discard_on 'NoSuchGem::Error'
      end

      setup do
        TestJob.events = []
        TestJob.raise_with = nil
      end

      teardown do
        TestJob.raise_with = nil
      end

      # A job as it comes back from the queue. +enqueued_at+ is what tells the callbacks that another
      # attempt will follow, and only +deserialize+ ever sets it — a job built with +new+ is inline.
      def queued_job(klass = TestJob, raise_with: nil)
        klass.raise_with = raise_with

        klass.new('key').tap { |job| job.enqueued_at = Time.current }
      end

      def events_of(*kinds)
        TestJob.events.filter { |event| event.first.in?(kinds) }
      end

      def notified_levels(&)
        levels = []
        ActiveSupport::Notifications.subscribed(->(name, *_) { levels << name }, /\A(error|failure)\.active_job\z/, &)
        levels
      end

      test 'the whole perform runs inside the concurrency lock' do
        job = queued_job
        wrapped = false
        job.define_singleton_method(:with_extended_concurrency_lock) do |&block|
          wrapped = true
          block.call
        end

        job.perform_now

        assert wrapped, 'perform must be wrapped, otherwise a job outliving its lock duration runs alongside its own duplicate'
        assert_equal [[:performed, nil], [:success, nil]], TestJob.events
      end

      test 'a queued job reports :error for every attempt that comes back and :failure for the last one' do
        job = queued_job(raise_with: StandardError.new('boom'))

        # attempts 1..9 are retried, so they come back and are reported as errors
        (DataCycleCore::JobExtensions::Callbacks::ATTEMPTS - 1).times { job.perform_now }

        assert_equal 9, events_of(:error).size
        assert_empty events_of(:failure)
        assert_equal 9, job.executions

        # the 10th has nothing left to come back for: it reports a failure and lets the error out
        assert_raises(StandardError) { job.perform_now }

        assert_equal [[:failure, :failure]], events_of(:failure)
        assert_equal 9, events_of(:error).size
      end

      test 'a failed attempt is pushed back in priority so it does not starve fresh work' do
        job = queued_job(raise_with: StandardError.new('boom'))
        priority = job.priority

        job.perform_now

        assert_equal priority + 1, job.priority
      end

      test 'an inline job fails on its first attempt: there is no queue to come back from' do
        TestJob.raise_with = StandardError.new('boom')
        job = TestJob.new('key')

        assert_nil job.enqueued_at
        assert_raises(StandardError) { job.perform_now }

        assert_equal [[:failure, :failure]], events_of(:failure)
        assert_empty events_of(:error)
      end

      test 'a job that discards its failure still reports it, but does not let it out' do
        job = queued_job(SwallowingJob, raise_with: StandardError.new('boom'))

        assert_nothing_raised { job.fail_permanently(StandardError.new('boom')) }
        assert_equal [[:failure, :failure]], events_of(:failure)
      end

      test 'an error that comes back is reported as :error, a final one as :failure' do
        retried = notified_levels { queued_job(raise_with: StandardError.new('boom')).perform_now }
        # SwallowingJob keeps the exception in, so only the level being asserted differs
        final = notified_levels { queued_job(SwallowingJob).fail_permanently(StandardError.new('boom')) }

        assert_equal ['error.active_job'], retried
        assert_equal ['failure.active_job'], final
      end

      test 'an exception that discard_on drops is not reported and runs no callbacks' do
        job = queued_job(raise_with: ActiveRecord::RecordNotFound.new('gone'))
        priority = job.priority

        levels = notified_levels { job.perform_now }

        assert_empty levels, 'a job dropped on purpose did not fail, so nothing should be logged for it'
        assert_empty events_of(:error, :failure)
        assert_equal priority, job.priority
      end

      test 'discard_on records its exceptions per class, so a subclass adds to what it inherits' do
        assert_includes DataCycleCore::ApplicationJob.discarded_exceptions, ActiveRecord::RecordNotFound
        assert_includes DataCycleCore::ApplicationJob.discarded_exceptions, ActiveJob::DeserializationError

        pdf_job = DataCycleCore::ExtractPdfTextContentJob

        assert_includes pdf_job.discarded_exceptions, PDF::Reader::MalformedPDFError
        assert_includes pdf_job.discarded_exceptions, ActiveRecord::RecordNotFound
        assert_not_includes DataCycleCore::ApplicationJob.discarded_exceptions, PDF::Reader::MalformedPDFError
      end

      test 'discarded_exception? matches subclasses of what was declared' do
        job = TestJob.new('key')

        assert job.discarded_exception?(ActiveRecord::RecordNotFound.new)
        assert_not job.discarded_exception?(StandardError.new)
      end

      test 'discard_on also records a class name given as a string, and resolves it when it is raised' do
        job = queued_job(StringDiscardJob, raise_with: TestError.new('gone'))

        assert_includes StringDiscardJob.discarded_exceptions, 'DataCycleCore::JobExtensions::CallbacksTest::TestError'

        levels = notified_levels { job.perform_now }

        assert_empty levels, 'an exception dropped by name is dropped on purpose too, so nothing should be logged for it'
        assert_empty events_of(:error, :failure)
      end

      test 'discarded_exception? ignores a class name that resolves to nothing' do
        job = UnresolvableDiscardJob.new('key')

        assert_includes UnresolvableDiscardJob.discarded_exceptions, 'NoSuchGem::Error'
        assert_not job.discarded_exception?(StandardError.new)
      end

      # the around_perform is registered before every other :perform callback so that it wraps them
      test 'a callback that raises before perform is reported like any other failure' do
        job = queued_job(FailingCallbackJob)
        priority = job.priority

        levels = notified_levels { job.perform_now }

        assert_equal ['error.active_job'], levels
        assert_equal [[:error, :error]], events_of(:error)
        assert_empty events_of(:performed)
        assert_equal priority + 1, job.priority
      end

      test 'a plain job refreshes the dashboard when it finishes, not when it starts' do
        job = queued_job
        broadcasts = 0

        DataCycleCore::StatsJobQueue.stub(:broadcast_throttled_jobs_reload, -> { broadcasts += 1 }) do
          job.perform_now
        end

        assert_equal 1, broadcasts
        assert_not TestJob.broadcast_dashboard_on_start
      end

      test 'importer jobs also refresh the dashboard when they start, since the panel lists them' do
        assert DataCycleCore::ImportJob.broadcast_dashboard_on_start
        assert DataCycleCore::DownloadJob.broadcast_dashboard_on_start
        assert_not DataCycleCore::CacheInvalidationJob.broadcast_dashboard_on_start
      end

      # MailDeliveryJob descends from ActionMailer's job, not from ApplicationJob, and picks up the
      # callbacks on its own — so it has to bring the lock helper the around_perform needs with it
      test 'a mailer job runs through the same callbacks without an ApplicationJob ancestor' do
        job = DataCycleCore::SubscriptionMailerJob.new('DataCycleCore::SubscriptionMailer', 'notify', 'deliver_now', args: [])

        assert_not_kind_of DataCycleCore::ApplicationJob, job
        assert_respond_to job, :with_extended_concurrency_lock
        assert_nil job.concurrency_key
        assert_equal(:done, job.with_extended_concurrency_lock { :done })
      end
    end
  end
end
