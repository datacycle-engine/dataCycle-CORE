# frozen_string_literal: true

module DataCycleCore
  module JobExtensions
    module Callbacks
      extend ActiveSupport::Concern

      # the +around_perform+ below holds the concurrency lock for the duration of the job, so every
      # class that gets the callbacks gets that too — MailDeliveryJob includes this one on its own
      include Persistence

      ATTEMPTS = 10

      included do
        attr_accessor :last_error, :last_error_level

        define_callbacks :success, :error, :failure

        # The exception classes handed to +discard_on+, as given — +discard_on+ also takes class
        # names as strings, and those are resolved at raise time rather than here. ActiveJob keeps
        # no public record of which of its rescue handlers drops an exception and which retries it,
        # so collect them on the way in — see +discarded_exception?+ for why the error path has to
        # be able to tell them apart.
        class_attribute :discarded_exceptions, instance_writer: false, default: []

        # Whether the dashboard is refreshed when this job *starts*, and not only when it is
        # enqueued and when it finishes. Every refresh re-runs the whole StatsJobQueue aggregate, so
        # it is worth it only for the jobs the dashboard lists individually and marks as running;
        # for the rest, starting just moves a counter that the next enqueue or finish picks up
        # anyway. This is what +broadcast_dashboard_jobs_now?+ decided before SolidQueue.
        class_attribute :broadcast_dashboard_on_start, instance_writer: false, default: false

        # Registered ahead of every other :perform callback on purpose: an around callback only
        # wraps what is registered after it, so anything declared below — the dashboard broadcast,
        # the :success callbacks, a subclass's own before_perform — would otherwise be able to raise
        # past the one handler whose job it is to report failures.
        around_perform do |job, block|
          job.with_extended_concurrency_lock(&block)
        rescue StandardError => e
          job.last_error = e

          # a discarded exception is dropped on purpose: there is nothing to report and nothing to
          # come back for
          raise if job.discarded_exception?(e)

          # to_i because a host-project job may include this without a priority of its own, and a
          # NoMethodError raised here would replace the failure this block exists to report
          job.priority = job.priority.to_i + 1

          # the last attempt runs the :failure callbacks via retry_on instead, and an inline job is
          # never retried at all, so only fire :error for attempts that will actually come back
          if job.enqueued_at.present? && job.executions < ATTEMPTS
            job.last_error_level = :error
            job.run_callbacks :error
          end

          raise
        end

        after_enqueue :broadcast_dashboard_jobs_reload
        before_perform :broadcast_dashboard_jobs_reload, if: :broadcast_dashboard_on_start
        after_perform :run_success_callbacks, :broadcast_dashboard_jobs_reload
        after_error :instrument_error
        after_failure :instrument_error, :broadcast_dashboard_jobs_reload

        # A subclass must not add a +retry_on+ of its own: +executions_for+ counts attempts per
        # handler, so a second one would no longer move in lockstep with +executions+ and the
        # :error/:failure split above would fire for the wrong attempts.
        retry_on StandardError, attempts: ATTEMPTS, wait: :polynomially_longer do |job, exception|
          job.fail_permanently(exception)
        end

        discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound
      end

      class_methods do
        def after_success(*filters, &)
          set_callback(:success, :after, *filters, &)
        end

        def after_error(*filters, &)
          set_callback(:error, :after, *filters, &)
        end

        def after_failure(*filters, &)
          set_callback(:failure, :after, *filters, &)
        end

        # remembers what ActiveJob does not expose afterwards, see +discarded_exceptions+
        def discard_on(*exceptions, **options, &)
          self.discarded_exceptions += exceptions

          super
        end
      end

      # Whether +discard_on+ will throw this exception away instead of retrying or failing the job.
      # The +:error+ callbacks must not run for one: subclasses use them to record a failure —
      # +WebhookJob+ marks its external sync as errored — and a job that was dropped on purpose
      # (a deleted record, an argument that no longer deserializes) did not fail.
      # String class names are resolved here rather than at declaration time, which is the point of
      # passing one to +discard_on+: the gem defining the exception may not be loaded yet.
      # @param exception [StandardError]
      # @return [Boolean]
      def discarded_exception?(exception)
        discarded_exceptions.any? do |klass|
          klass = klass.to_s.safe_constantize unless klass.is_a?(Module)

          klass.is_a?(Module) && exception.is_a?(klass)
        end
      end

      # Gives up on the job: reports the failure and lets it out to the caller, unless the job opted
      # into swallowing it via +discard_on_failure?+.
      # @param exception [StandardError] the failure to report
      # @return [void]
      def fail_permanently(exception)
        self.last_error = exception
        self.last_error_level = :failure
        run_callbacks :failure

        raise exception unless try(:discard_on_failure?)
      end

      # +retry_on+ cannot tell an inline run from a queued one, so a failing +perform_now+ would be
      # pushed into the queue for a later attempt and its exception swallowed: the caller — a
      # +dc:import:*+ task with +run_now=true+, or a synchronous webhook export — would see success
      # for a job that failed, and the job would then run again in the background. There is no queue
      # to come back from, so the first failure of an inline job is final. This is the guard the
      # pre-SolidQueue +rescue_from+ expressed as +enqueued_at.present?+.
      def retry_job(options = {})
        return super if enqueued_at.present?

        fail_permanently(options[:error] || last_error)
      end

      private

      def run_success_callbacks
        run_callbacks :success
      end

      def instrument_error
        self.last_error_level ||= :error

        ActiveSupport::Notifications.instrument "#{last_error_level}.active_job", {
          adapter: queue_adapter,
          job: self,
          error: last_error,
          exception: [last_error.class.name, last_error.message],
          exception_object: last_error
        }
      end

      def broadcast_dashboard_jobs_reload
        DataCycleCore::StatsJobQueue.broadcast_throttled_jobs_reload
      end
    end
  end
end
