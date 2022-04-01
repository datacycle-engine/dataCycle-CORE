# frozen_string_literal: true

class CreateDelayedJobs < ActiveRecord::Migration[5.0]
  def self.up
    create_table :delayed_jobs, force: true do |table|
      table.integer :priority, default: 0, null: false # Allows some jobs to jump to the front of the queue
      table.integer :attempts, default: 0, null: false # Provides for retries, but still fail eventually.
      table.text :handler,                 null: false # YAML-encoded string of the object that will do work
      table.text :last_error                           # reason for last failure (See Note below)
      table.datetime :run_at                           # When to run. Could be Time.zone.now for immediately, or sometime in the future.
      table.datetime :locked_at                        # Set when a client is working on this object
      table.datetime :failed_at                        # Set when all retries have failed (actually, by default, the record is deleted instead)
      table.string :locked_by                          # Who is working on this object (if locked)
      table.string :queue                              # The name of the queue this job is in
      table.string :delayed_reference_id
      table.string :delayed_reference_type
      table.timestamps null: true
    end

    add_index :delayed_jobs, [:priority, :run_at], name: 'delayed_jobs_priority'
    add_index :delayed_jobs, [:queue], name: 'delayed_jobs_queue'
    add_index :delayed_jobs, [:delayed_reference_id], name: 'delayed_jobs_delayed_reference_id'
    add_index :delayed_jobs, [:delayed_reference_type], name: 'delayed_jobs_delayed_reference_type'

    add_column :external_sources, :last_download, :timestamp
    add_column :external_sources, :last_import, :timestamp
  end

  def self.down
    remove_column :external_sources, :last_download, :timestamp
    remove_column :external_sources, :last_import, :timestamp
    drop_table :delayed_jobs
  end
end
