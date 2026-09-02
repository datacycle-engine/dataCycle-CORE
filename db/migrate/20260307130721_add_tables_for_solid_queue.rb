# frozen_string_literal: true

class AddTablesForSolidQueue < ActiveRecord::Migration[8.0]
  # The table definitions are solid_queue's own, but NOT its +force: :cascade+: in a migration that
  # emits +DROP TABLE IF EXISTS … CASCADE+ first, so on a database that already has the tables —
  # someone ran +solid_queue:install+ by hand — it would silently destroy every queued job, and once
  # 20260321095704 has run the CASCADE would take the active_job_statistics view with it, leaving
  # StatsJobQueue broken with nothing failing at migration time.
  #
  # +if_not_exists: true+ instead, here and on the foreign keys, so the whole migration is
  # idempotent. The trade-off is that a table created by a different solid_queue version keeps its
  # own definition rather than being corrected here — the better failure of the two, because a schema
  # can still be fixed afterwards while destroyed jobs cannot be brought back.
  def change
    create_table 'solid_queue_blocked_executions', if_not_exists: true do |t|
      t.bigint 'job_id', null: false
      t.string 'queue_name', null: false
      t.integer 'priority', default: 0, null: false
      t.string 'concurrency_key', null: false
      t.datetime 'expires_at', null: false
      t.datetime 'created_at', null: false
      t.index ['concurrency_key', 'priority', 'job_id'], name: 'index_solid_queue_blocked_executions_for_release'
      t.index ['expires_at', 'concurrency_key'], name: 'index_solid_queue_blocked_executions_for_maintenance'
      t.index ['job_id'], name: 'index_solid_queue_blocked_executions_on_job_id', unique: true
    end

    create_table 'solid_queue_claimed_executions', if_not_exists: true do |t|
      t.bigint 'job_id', null: false
      t.bigint 'process_id'
      t.datetime 'created_at', null: false
      t.index ['job_id'], name: 'index_solid_queue_claimed_executions_on_job_id', unique: true
      t.index ['process_id', 'job_id'], name: 'index_solid_queue_claimed_executions_on_process_id_and_job_id'
    end

    create_table 'solid_queue_failed_executions', if_not_exists: true do |t|
      t.bigint 'job_id', null: false
      t.text 'error'
      t.datetime 'created_at', null: false
      t.index ['job_id'], name: 'index_solid_queue_failed_executions_on_job_id', unique: true
    end

    create_table 'solid_queue_jobs', if_not_exists: true do |t|
      t.string 'queue_name', null: false
      t.string 'class_name', null: false
      t.text 'arguments'
      t.integer 'priority', default: 0, null: false
      # solid_queue's own schema types this as a string; uuid matches the rest of this database and
      # every id ActiveJob generates (SecureRandom.uuid). It does couple us to that: a job_id that is
      # not a UUID — a hand-inserted row, or an ActiveJob that ever changes how it builds one — would
      # raise on insert instead of being stored as-is, and a lookup by one raises rather than coming
      # back empty, which is what anything written against upstream's schema (mission_control-jobs)
      # would expect.
      t.uuid 'active_job_id'
      t.datetime 'scheduled_at'
      t.datetime 'finished_at'
      t.string 'concurrency_key'
      t.datetime 'created_at', null: false
      t.datetime 'updated_at', null: false
      t.index ['active_job_id'], name: 'index_solid_queue_jobs_on_active_job_id'
      t.index ['class_name'], name: 'index_solid_queue_jobs_on_class_name'
      t.index ['finished_at'], name: 'index_solid_queue_jobs_on_finished_at'
      t.index ['queue_name', 'finished_at'], name: 'index_solid_queue_jobs_for_filtering'
      t.index ['scheduled_at', 'finished_at'], name: 'index_solid_queue_jobs_for_alerting'
    end

    create_table 'solid_queue_pauses', if_not_exists: true do |t|
      t.string 'queue_name', null: false
      t.datetime 'created_at', null: false
      t.index ['queue_name'], name: 'index_solid_queue_pauses_on_queue_name', unique: true
    end

    create_table 'solid_queue_processes', if_not_exists: true do |t|
      t.string 'kind', null: false
      t.datetime 'last_heartbeat_at', null: false
      t.bigint 'supervisor_id'
      t.integer 'pid', null: false
      t.string 'hostname'
      t.text 'metadata'
      t.datetime 'created_at', null: false
      t.string 'name', null: false
      t.index ['last_heartbeat_at'], name: 'index_solid_queue_processes_on_last_heartbeat_at'
      t.index ['name', 'supervisor_id'], name: 'index_solid_queue_processes_on_name_and_supervisor_id', unique: true
      t.index ['supervisor_id'], name: 'index_solid_queue_processes_on_supervisor_id'
    end

    create_table 'solid_queue_ready_executions', if_not_exists: true do |t|
      t.bigint 'job_id', null: false
      t.string 'queue_name', null: false
      t.integer 'priority', default: 0, null: false
      t.datetime 'created_at', null: false
      t.index ['job_id'], name: 'index_solid_queue_ready_executions_on_job_id', unique: true
      t.index ['priority', 'job_id'], name: 'index_solid_queue_poll_all'
      t.index ['queue_name', 'priority', 'job_id'], name: 'index_solid_queue_poll_by_queue'
    end

    create_table 'solid_queue_recurring_executions', if_not_exists: true do |t|
      t.bigint 'job_id', null: false
      t.string 'task_key', null: false
      t.datetime 'run_at', null: false
      t.datetime 'created_at', null: false
      t.index ['job_id'], name: 'index_solid_queue_recurring_executions_on_job_id', unique: true
      t.index ['task_key', 'run_at'], name: 'index_solid_queue_recurring_executions_on_task_key_and_run_at', unique: true
    end

    create_table 'solid_queue_recurring_tasks', if_not_exists: true do |t|
      t.string 'key', null: false
      t.string 'schedule', null: false
      t.string 'command', limit: 2048
      t.string 'class_name'
      t.text 'arguments'
      t.string 'queue_name'
      t.integer 'priority', default: 0
      t.boolean 'static', default: true, null: false
      t.text 'description'
      t.datetime 'created_at', null: false
      t.datetime 'updated_at', null: false
      t.index ['key'], name: 'index_solid_queue_recurring_tasks_on_key', unique: true
      t.index ['static'], name: 'index_solid_queue_recurring_tasks_on_static'
    end

    create_table 'solid_queue_scheduled_executions', if_not_exists: true do |t|
      t.bigint 'job_id', null: false
      t.string 'queue_name', null: false
      t.integer 'priority', default: 0, null: false
      t.datetime 'scheduled_at', null: false
      t.datetime 'created_at', null: false
      t.index ['job_id'], name: 'index_solid_queue_scheduled_executions_on_job_id', unique: true
      t.index ['scheduled_at', 'priority', 'job_id'], name: 'index_solid_queue_dispatch_all'
    end

    create_table 'solid_queue_semaphores', if_not_exists: true do |t|
      t.string 'key', null: false
      t.integer 'value', default: 1, null: false
      t.datetime 'expires_at', null: false
      t.datetime 'created_at', null: false
      t.datetime 'updated_at', null: false
      t.index ['expires_at'], name: 'index_solid_queue_semaphores_on_expires_at'
      t.index ['key', 'value'], name: 'index_solid_queue_semaphores_on_key_and_value'
      t.index ['key'], name: 'index_solid_queue_semaphores_on_key', unique: true
    end

    add_foreign_key 'solid_queue_blocked_executions', 'solid_queue_jobs', column: 'job_id', on_delete: :cascade, if_not_exists: true
    add_foreign_key 'solid_queue_claimed_executions', 'solid_queue_jobs', column: 'job_id', on_delete: :cascade, if_not_exists: true
    add_foreign_key 'solid_queue_failed_executions', 'solid_queue_jobs', column: 'job_id', on_delete: :cascade, if_not_exists: true
    add_foreign_key 'solid_queue_ready_executions', 'solid_queue_jobs', column: 'job_id', on_delete: :cascade, if_not_exists: true
    add_foreign_key 'solid_queue_recurring_executions', 'solid_queue_jobs', column: 'job_id', on_delete: :cascade, if_not_exists: true
    add_foreign_key 'solid_queue_scheduled_executions', 'solid_queue_jobs', column: 'job_id', on_delete: :cascade, if_not_exists: true
  end
end
