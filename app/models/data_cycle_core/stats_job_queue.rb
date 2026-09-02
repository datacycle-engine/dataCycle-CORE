# frozen_string_literal: true

module DataCycleCore
  # Backed by the active_job_statistics view, which has no id column. The view groups by queue_name,
  # so that column identifies a row on its own.
  class StatsJobQueue < ApplicationRecord
    self.table_name = 'active_job_statistics'
    self.implicit_order_column = :queue_name

    # the per-queue counter columns exposed by the active_job_statistics view; each also has a
    # matching "<state>_types" array column
    STATES = [:queued, :running, :failed].freeze

    # one importer queue row together with the ActiveJob it carries
    ImporterJob = Data.define(:active_job, :row)

    # How many importer jobs the dashboard lists individually. Every row costs an
    # ActiveJob::Base.deserialize and this whole list is rebuilt on every dashboard broadcast, so the
    # scan has to be bounded — a list this long is unreadable anyway, and the per-queue counters
    # above it are unaffected.
    IMPORTER_LIST_LIMIT = 100

    def readonly?
      true
    end

    def runnable_types
      Array.wrap(queued_types) + Array.wrap(running_types)
    end

    def job_list
      return @job_list if defined? @job_list

      @job_list = {}
      importer_list = importer_jobs

      external_system_names =
        if importer_list.present?
          DataCycleCore::ExternalSystem
            .where(id: importer_list.map { |i| i.active_job.external_system_id }.uniq)
            .pluck(:id, :name)
            .to_h
        else
          {}
        end

      @job_list[:importers] = importer_list.map do |importer|
        {
          'id' => importer.row.id,
          'status' => importer.row.claimed? ? 'running' : 'queued',
          'job' => importer.active_job.import_type,
          'created_at' => importer.row.created_at,
          'external_system_name' => external_system_names[importer.active_job.external_system_id]
        }
      end

      data = self.class.all.to_a

      STATES.each { |state| @job_list[state] = data.filter(&state).pluck(:queue_name, state).to_h }
      @job_list[:job_types] = data.to_h { |d| [d.queue_name, d.attributes.slice(*STATES.map { |s| "#{s}_types" })] }

      @job_list
    end

    def self.broadcast_throttled_jobs_reload
      DataCycleCore::Turbo::ThreadThrottler.for('broadcast_admin_dashboard_jobs', interval: 2).throttle do
        broadcast_jobs_reload({ data: { throttle: 2 } })
      end
    end

    def self.broadcast_jobs_reload(attributes = {})
      stat_job_queue = new.job_list
      TurboService.broadcast_localized_update_to(
        'admin_dashboard_jobs',
        target: 'jobs_queue_title',
        partial: 'data_cycle_core/dash_board/job_queue_title',
        locals: { stat_job_queue: },
        attributes:
      )
      TurboService.broadcast_localized_update_to(
        'admin_dashboard_jobs',
        target: 'jobs_queue_body',
        partial: 'data_cycle_core/dash_board/job_queue_body',
        locals: { stat_job_queue: },
        attributes:
      )
    end

    private

    # The oldest outstanding importer jobs, at most +IMPORTER_LIST_LIMIT+ of them.
    # @return [Array<ImporterJob>]
    def importer_jobs
      # one row over the limit, so a truncated list can be told apart from an exactly full one
      rows = SolidQueue::Job.live
        .where(queue_name: DataCycleCore.importer_queues)
        .includes(:claimed_execution)
        .order(created_at: :asc)
        .limit(IMPORTER_LIST_LIMIT + 1)
        .to_a

      if rows.size > IMPORTER_LIST_LIMIT
        Rails.logger.warn("StatsJobQueue lists only the oldest #{IMPORTER_LIST_LIMIT} importer jobs")
        rows = rows.first(IMPORTER_LIST_LIMIT)
      end

      rows.filter_map { |row| importer_job_for(row) }
    end

    # The importer job behind a queue row, or nil when the row is of no interest or cannot be read. A
    # row can outlive the code that enqueued it: a renamed or removed job class makes +deserialize+
    # raise NameError, and an argument referencing a deleted record raises
    # ActiveJob::DeserializationError. Reading plain columns could not fail, so before SolidQueue a
    # single stale row was harmless — it must not take the whole admin dashboard down now.
    # @return [ImporterJob, nil]
    def importer_job_for(row)
      active_job = ActiveJob::Base.deserialize(row.arguments)
      active_job.send(:deserialize_arguments_if_needed)

      # importer jobs are keyed by the external system's UUID and describe themselves via import_type
      return unless active_job.try(:external_system_id).to_s.uuid?
      return unless active_job.respond_to?(:import_type)

      ImporterJob.new(active_job:, row:)
    rescue StandardError => e
      Rails.logger.warn("StatsJobQueue skipped unreadable job #{row.id}: #{e.class}: #{e.message}")
      nil
    end
  end
end
