# frozen_string_literal: true

module DataCycleCore
  class WatchListSubscriberNotificationJob < ApplicationJob
    queue_as :mailers
    queue_with_priority 10

    NOTIFY_METHOD = 'notify_changed_watch_list_items'

    def perform(watch_list, current_user, content_ids, type)
      watch_list.subscriptions.except_user_id(current_user.id).users.find_each do |user|
        changed_items = take_over_pending_notification(user)

        changed_items[watch_list.id] = [] unless changed_items.key?(watch_list.id)
        content_ids.each do |id|
          deleted = changed_items[watch_list.id].reject! { |item| item[:id] == id }
          changed_items[watch_list.id].push({ type:, id:, user_id: current_user.id }) if deleted.blank?
        end

        SubscriptionMailer.notify_changed_watch_list_items(user, changed_items).deliver_later(wait_until: delivery_time(user))
      end
    end

    private

    # Takes the changed items of this user's still undelivered digest over into the mail we are
    # about to enqueue and destroys the job that would have sent the old one, so repeated changes
    # coalesce into a single mail. Returns an empty hash when there is nothing to coalesce.
    #
    # Deleting the execution row is the gate, and it has to be the first write: it is the same row a
    # dispatcher or a worker has to take to move the job on, so exactly one of us gets it. If we
    # did, the job can no longer be picked up and is ours to destroy. If we deleted nothing, a
    # worker has already claimed it — then we leave it alone and the user simply gets a second mail,
    # because destroying a claimed job cascades its claimed execution away mid-run, losing the
    # digest and leaving the worker to finalize a row that no longer exists.
    #
    # Locking the solid_queue_jobs row instead would serialize against nobody: claiming takes
    # `FOR UPDATE SKIP LOCKED` on solid_queue_ready_executions and inserts into
    # solid_queue_claimed_executions (SolidQueue::ReadyExecution.claim), and never touches
    # solid_queue_jobs at all.
    def take_over_pending_notification(user)
      SolidQueue::Job.transaction do
        job = queued_notification_for(user)
        next {} unless job && runnable_row_taken?(job)

        pending_changed_items(job).tap { job.destroy }
      end
    end

    # Deletes whichever execution row still makes the job runnable and reports whether it was there
    # to delete. A due job is moved from scheduled to ready inside one transaction
    # (SolidQueue::ScheduledExecution.dispatch_next_batch), so it always has exactly one of the two,
    # and SubscriptionMailerJob declares no `limits_concurrency`, so it is never blocked either.
    def runnable_row_taken?(job)
      (SolidQueue::ScheduledExecution.where(job_id: job.id).delete_all +
        SolidQueue::ReadyExecution.where(job_id: job.id).delete_all).positive?
    end

    # The pending (not yet delivered) SolidQueue job that would send this user their watch-list
    # digest, if any. Replaces the delayed_job `find_by_identifiers` lookup, including its
    # `include_locked: false, include_failed: false` defaults — a claimed job must not be taken over
    # (see above) and a failed one still belongs to the retry machinery, not to us. Both are
    # narrowing here rather than load-bearing; `runnable_row_taken?` is what actually decides.
    # Matches the queued SubscriptionMailerJob by its mailer method and the recipient's GlobalID
    # inside the serialized job arguments
    # (["…SubscriptionMailer", "notify_changed_watch_list_items", "deliver_now", {"args" => [<user gid>, <changed_items>]}]).
    def queued_notification_for(user)
      SolidQueue::Job
        .where(class_name: DataCycleCore::SubscriptionMailerJob.name, finished_at: nil)
        .where.missing(:claimed_execution, :failed_execution)
        .where("solid_queue_jobs.arguments::jsonb -> 'arguments' ->> 1 = ?", NOTIFY_METHOD)
        .where("solid_queue_jobs.arguments::jsonb -> 'arguments' -> 3 -> 'args' -> 0 ->> '_aj_globalid' = ?", user.to_global_id.to_s)
        .order(:created_at)
        .first
    end

    # The changed_items hash carried by an already-queued notification (arguments[3][:args][1]),
    # or an empty hash when that notification carried none.
    def pending_changed_items(solid_queue_job)
      job = ActiveJob::Base.deserialize(solid_queue_job.arguments)
      job.send(:deserialize_arguments_if_needed)
      job.arguments.dig(3, :args, 1) || {}
    end

    def delivery_time(user)
      Time.zone.now.try("end_of_#{user.notification_frequency}") || 5.minutes.from_now
    end
  end
end
