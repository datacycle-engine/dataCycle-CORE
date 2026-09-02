# frozen_string_literal: true

# lib/data_cycle_core.rb no longer requires delayed_job, so this migration has to pull in Delayed::Job
# itself. It is the last consumer of the gemspec dependency — see the note there.
require 'delayed_job_active_record'

class MigrateDelayedJobsToSolidQueue < ActiveRecord::Migration[8.0]
  def up
    # Only jobs that are waiting are moved: a locked one is being executed right now by a worker that
    # still has to finalize its row, and a failed one is a decision someone has to look at, not work
    # to carry over. Both are left behind on purpose, so report them — the operator running the
    # upgrade is the only one who can tell whether what stays is expected.
    scope = Delayed::Job.where(locked_at: nil, failed_at: nil, locked_by: nil)
    migrated = 0
    failed = 0

    scope.find_each do |job|
      ActiveJob::Base.deserialize(job.payload_object.job_data).enqueue

      job.destroy
      migrated += 1
    rescue StandardError => e
      failed += 1
      say "failed to migrate Delayed::Job #{job.id}: #{e.class}: #{e.message}"
      Rails.logger.error "Failed to migrate Delayed::Job with ID #{job.id}: #{e.message}"
    end

    say "migrated #{migrated} job(s) to SolidQueue, #{failed} failed, #{Delayed::Job.count} left in delayed_jobs (locked or failed)"
  end

  def down
  end
end
