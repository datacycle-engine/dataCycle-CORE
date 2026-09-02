# frozen_string_literal: true

class AddNewActiveJobStatisticsView < ActiveRecord::Migration[8.0]
  # `sum(1) FILTER (...)` is load-bearing and not a stylistic wart: over a group where nothing matches
  # it returns NULL, while `count(*) FILTER (...)` would return 0. DataCycleCore::StatsJobQueue#job_list
  # drops empty states with `data.filter(&state)`, and 0 is truthy in Ruby — counting instead of
  # summing would list every queue under every state with a zero next to it.
  def up
    execute <<~SQL.squish
      DROP VIEW IF EXISTS delayed_jobs_statistics;

      CREATE OR REPLACE VIEW active_job_statistics AS
      SELECT solid_queue_jobs.queue_name AS queue_name,
        sum(1) FILTER (
            WHERE solid_queue_failed_executions.id IS NOT NULL
        ) AS failed,
        sum(1) FILTER (
            WHERE solid_queue_claimed_executions.id IS NOT NULL
        ) AS running,
        sum(1) FILTER (
            WHERE solid_queue_ready_executions.id IS NOT NULL
              OR solid_queue_blocked_executions.id IS NOT NULL
              OR solid_queue_scheduled_executions.id IS NOT NULL
        ) AS queued,
        array_agg(DISTINCT class_name) FILTER (
            WHERE solid_queue_failed_executions.id IS NOT NULL
        ) AS failed_types,
        array_agg(DISTINCT class_name) FILTER (
            WHERE solid_queue_claimed_executions.id IS NOT NULL
        ) AS running_types,
        array_agg(DISTINCT class_name) FILTER (
            WHERE solid_queue_ready_executions.id IS NOT NULL
              OR solid_queue_blocked_executions.id IS NOT NULL
              OR solid_queue_scheduled_executions.id IS NOT NULL
        ) AS queued_types
      FROM solid_queue_jobs
        LEFT OUTER JOIN solid_queue_failed_executions ON solid_queue_failed_executions.job_id = solid_queue_jobs.id
        LEFT OUTER JOIN solid_queue_claimed_executions ON solid_queue_claimed_executions.job_id = solid_queue_jobs.id
        LEFT OUTER JOIN solid_queue_ready_executions ON solid_queue_ready_executions.job_id = solid_queue_jobs.id
        LEFT OUTER JOIN solid_queue_blocked_executions ON solid_queue_blocked_executions.job_id = solid_queue_jobs.id
        LEFT OUTER JOIN solid_queue_scheduled_executions ON solid_queue_scheduled_executions.job_id = solid_queue_jobs.id
      GROUP BY solid_queue_jobs.queue_name;
    SQL
  end

  def down
    # delayed_jobs_statistics is deliberately not restored: delayed_job is gone as of this release,
    # so its source table may no longer exist.
    execute 'DROP VIEW IF EXISTS active_job_statistics;'
  end
end
