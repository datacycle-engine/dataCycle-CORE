# frozen_string_literal: true

class AdjustDelayedJobIndizes < ActiveRecord::Migration[7.1]
  def change
    remove_index :delayed_jobs, :queue, name: 'delayed_jobs_queue'
    add_index :delayed_jobs, [:queue, :delayed_reference_type], name: 'index_delayed_jobs_on_queue_and_type'
  end
end
