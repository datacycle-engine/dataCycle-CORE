# frozen_string_literal: true

class AddMailerRecipientIndexToSolidQueueJobs < ActiveRecord::Migration[8.0]
  def change
    # DataCycleCore::WatchListSubscriberNotificationJob coalesces watch-list digests by looking up the
    # pending mail of one recipient inside the serialized job arguments — once per subscriber of the
    # watch list, so once per row of a `find_each`. Without an index that is a sequential scan of
    # solid_queue_jobs per subscriber.
    #
    # A GIN index on the whole document would not be used: the predicate is an equality on a scalar
    # at a known path, not a containment test. A partial b-tree index on exactly that path is, and it
    # only covers the rows that can ever match. The class name in the predicate is what keeps the
    # index small; renaming the job would leave the lookup unindexed, not broken.
    add_index :solid_queue_jobs,
              "((arguments::jsonb -> 'arguments' -> 3 -> 'args' -> 0 ->> '_aj_globalid'))",
              where: "class_name = 'DataCycleCore::SubscriptionMailerJob' AND finished_at IS NULL",
              name: 'index_solid_queue_jobs_on_mailer_recipient',
              if_not_exists: true
  end
end
