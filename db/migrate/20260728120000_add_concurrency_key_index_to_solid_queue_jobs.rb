# frozen_string_literal: true

class AddConcurrencyKeyIndexToSolidQueueJobs < ActiveRecord::Migration[8.0]
  def change
    # DataCycleCore::JobExtensions::Persistence#duplicate_queued_with_args? looks up live jobs by
    # concurrency_key + class_name. solid_queue ships indexes on class_name and on
    # (queue_name, finished_at), but none on concurrency_key, so that lookup would fall back to
    # scanning every job of the class on each dashboard import click and each import rake task.
    add_index :solid_queue_jobs, [:concurrency_key, :class_name], name: 'index_solid_queue_jobs_on_concurrency_key_and_class', if_not_exists: true
  end
end
