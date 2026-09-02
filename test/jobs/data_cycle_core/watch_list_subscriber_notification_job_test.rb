# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class WatchListSubscriberNotificationJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'notifies every subscribed user except the acting one' do
      subscriber = Object.new
      subscriber.define_singleton_method(:id) { 'user-2' }
      subscriber.define_singleton_method(:notification_frequency) { 'day' }
      subscriber.define_singleton_method(:to_global_id) { 'gid://dummy/DataCycleCore::User/user-2' }

      users_relation = Object.new
      users_relation.define_singleton_method(:find_each) { |&block| block.call(subscriber) }

      except_relation = Object.new
      except_relation.define_singleton_method(:users) { users_relation }

      subscriptions = Object.new
      subscriptions.define_singleton_method(:except_user_id) { |_id| except_relation }

      watch_list = Object.new
      watch_list.define_singleton_method(:id) { 'wl-1' }
      watch_list.define_singleton_method(:subscriptions) { subscriptions }

      current_user = Object.new
      current_user.define_singleton_method(:id) { 'user-1' }

      delivered = []
      mail = Object.new
      mail.define_singleton_method(:deliver_later) { |wait_until:| delivered << wait_until }

      DataCycleCore::SubscriptionMailer.stub(:notify_changed_watch_list_items, lambda { |user, changed_items|
        assert_equal subscriber, user
        assert_equal [{ type: 'add', id: 'c1', user_id: 'user-1' }], changed_items['wl-1']
        mail
      }) do
        DataCycleCore::WatchListSubscriberNotificationJob.perform_now(watch_list, current_user, ['c1'], 'add')
      end

      assert_equal 1, delivered.size
    end

    OLD_CHANGE = { type: 'add', id: 'c-old', user_id: 'user-1' }.freeze
    NEW_CHANGE = { type: 'add', id: 'c-new', user_id: 'user-1' }.freeze

    # A digest already queued for this recipient, holding one pending change on watch list wl-1.
    # Created without a scheduled_at, so SolidQueue readies it right away.
    def queued_digest_for(recipient, changed_items = { 'wl-1' => [OLD_CHANGE] })
      job = DataCycleCore::SubscriptionMailerJob.new(
        'DataCycleCore::SubscriptionMailer',
        DataCycleCore::WatchListSubscriberNotificationJob::NOTIFY_METHOD,
        'deliver_now',
        args: [recipient, changed_items]
      )

      SolidQueue::Job.create!(queue_name: 'mailers', class_name: DataCycleCore::SubscriptionMailerJob.name, arguments: job.serialize)
    end

    # The watch list, its subscriptions and the acting user, stubbed down to what +perform+ touches:
    # +subscriptions.except_user_id(id).users.find_each+ plus the two ids.
    def stub_watch_list(recipient)
      users_relation = Object.new
      users_relation.define_singleton_method(:find_each) { |&block| block.call(recipient) }
      except_relation = Object.new
      except_relation.define_singleton_method(:users) { users_relation }
      subscriptions = Object.new
      subscriptions.define_singleton_method(:except_user_id) { |_id| except_relation }

      watch_list = Object.new
      watch_list.define_singleton_method(:id) { 'wl-1' }
      watch_list.define_singleton_method(:subscriptions) { subscriptions }
      current_user = Object.new
      current_user.define_singleton_method(:id) { 'user-1' }

      [watch_list, current_user]
    end

    # Runs the job and returns the wl-1 change list of every mail it handed to the mailer.
    def delivered_changes_for(recipient, content_ids)
      watch_list, current_user = stub_watch_list(recipient)
      mail = Object.new
      mail.define_singleton_method(:deliver_later) { |wait_until:| _ = wait_until }
      captured = []

      DataCycleCore::SubscriptionMailer.stub(:notify_changed_watch_list_items, lambda { |_user, changed_items|
        captured << changed_items['wl-1']
        mail
      }) do
        DataCycleCore::WatchListSubscriberNotificationJob.perform_now(watch_list, current_user, content_ids, 'add')
      end

      captured
    end

    test 'coalesces a new change into the same user\'s already-queued notification' do
      recipient = DataCycleCore::User.first
      skip 'no user seeded' if recipient.nil?

      sq_job = queued_digest_for(recipient)

      merged = delivered_changes_for(recipient, ['c-new'])

      # the previously-queued notification is replaced ...
      assert_not SolidQueue::Job.exists?(sq_job.id)
      # ... and its pending change is merged with the new one
      assert_equal [[OLD_CHANGE, NEW_CHANGE]], merged
    end

    # Deleting the row that makes the queued digest runnable is the gate that closes the race with a
    # worker: only whoever wins that delete may destroy the job. Losing it has to cost a coalesce, not
    # the mail — destroying a claimed job would cascade its claimed execution away mid-run.
    test 'leaves a queued notification alone when its runnable row is already gone' do
      recipient = DataCycleCore::User.first
      skip 'no user seeded' if recipient.nil?

      sq_job = queued_digest_for(recipient)
      # exactly what a worker claiming the job between the lookup and the delete leaves behind
      assert_equal 1, SolidQueue::ReadyExecution.where(job_id: sq_job.id).delete_all

      separate = delivered_changes_for(recipient, ['c-new'])

      # the job survives to deliver the digest it already carries ...
      assert SolidQueue::Job.exists?(sq_job.id)
      # ... and the new change goes out as a second mail rather than being merged into it
      assert_equal [[NEW_CHANGE]], separate
    end

    # The lookup filter in front of the gate: a claimed job is never even a candidate.
    test 'never takes over a notification a worker has already claimed' do
      recipient = DataCycleCore::User.first
      skip 'no user seeded' if recipient.nil?

      sq_job = queued_digest_for(recipient)
      SolidQueue::ReadyExecution.where(job_id: sq_job.id).delete_all
      SolidQueue::ClaimedExecution.create!(job_id: sq_job.id, created_at: Time.current)

      separate = delivered_changes_for(recipient, ['c-new'])

      assert SolidQueue::Job.exists?(sq_job.id)
      assert_equal [[NEW_CHANGE]], separate
    end
  end
end
