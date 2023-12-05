# frozen_string_literal: true

class AddViewForDelayedJobStatistics < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE VIEW delayed_jobs_statistics AS
      SELECT delayed_jobs.queue AS "queue_name",
        SUM(1) filter (
          WHERE delayed_jobs.failed_at IS NOT NULL
        ) AS "failed",
        SUM(1) filter (
          WHERE delayed_jobs.failed_at IS NULL
            AND delayed_jobs.locked_at IS NOT NULL
            AND delayed_jobs.locked_by IS NOT NULL
        ) AS "running",
        SUM(1) filter (
          WHERE delayed_jobs.failed_at IS NULL
            AND delayed_jobs.locked_at IS NULL
            AND delayed_jobs.locked_by IS NULL
        ) AS "queued",
        array_agg(DISTINCT delayed_jobs.delayed_reference_type) filter (
          WHERE delayed_jobs.failed_at IS NOT NULL
        ) AS "failed_types",
        array_agg(DISTINCT delayed_jobs.delayed_reference_type) filter (
          WHERE delayed_jobs.failed_at IS NULL
            AND delayed_jobs.locked_at IS NOT NULL
            AND delayed_jobs.locked_by IS NOT NULL
        ) AS "running_types",
        array_agg(DISTINCT delayed_jobs.delayed_reference_type) filter (
          WHERE delayed_jobs.failed_at IS NULL
            AND delayed_jobs.locked_at IS NULL
            AND delayed_jobs.locked_by IS NULL
        ) AS "queued_types"
      FROM delayed_jobs
      GROUP BY delayed_jobs.queue;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW IF EXISTS delayed_jobs_statistics;
    SQL
  end
end
