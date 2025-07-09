# frozen_string_literal: true

module DataCycleCore
  class StatsJobQueue < ApplicationRecord
    self.table_name = 'delayed_jobs_statistics'

    def readonly?
      true
    end

    def runnable_types
      Array.wrap(queued_types) + Array.wrap(running_types)
    end

    def job_list
      return @job_list if defined? @job_list

      @job_list = {
        importers: [],
        running: [],
        queued: [],
        failed: []
      }
      jobs_list = Delayed::Job.where(failed_at: nil, queue: 'importers')
        .order(created_at: :asc)
        .filter { |job| job.delayed_reference_id.to_s.uuid? }
      if jobs_list.present?
        external_system_names = DataCycleCore::ExternalSystem
          .where(id: jobs_list.pluck(:delayed_reference_id))
          .pluck(:id, :name)
          .to_h
      end
      jobs_list.each do |job|
        if job.locked_at.nil? && job.locked_by.nil?
          @job_list[:importers].push(
            {
              'id' => job.id,
              'status' => 'queued',
              'job' => job.delayed_reference_type,
              'ref_id' => job.delayed_reference_id,
              'created_at' => job.created_at,
              'external_system_name' => external_system_names[job.delayed_reference_id]
            }
          )
        else
          @job_list[:importers].push(
            {
              'id' => job.id,
              'status' => 'running',
              'job' => job.delayed_reference_type,
              'ref_id' => job.delayed_reference_id,
              'created_at' => job.created_at.time,
              'external_system_name' => external_system_names[job.delayed_reference_id]
            }
          )
        end
      end

      data = self.class.all.to_a

      @job_list[:queued] = data.filter(&:queued).pluck(:queue_name, :queued).to_h
      @job_list[:running] = data.filter(&:running).pluck(:queue_name, :running).to_h
      @job_list[:failed] = data.filter(&:failed).pluck(:queue_name, :failed).to_h
      @job_list[:delayed_reference_types] = data.to_h { |d| [d.queue_name, d.attributes.slice('queued_types', 'running_types', 'failed_types')] }

      @job_list
    end

    def rebuilding_classification_mappings?
      query = self.class.where(queue_name: DataCycleCore::RebuildClassificationMappingsJob.queue_as)
      query = query.where('running_types @> ?', ['RebuildClassificationMappingsJob'].to_pg_array)
        .or(query.where('queued_types @> ?', ['RebuildClassificationMappingsJob'].to_pg_array))

      query.exists?
    end

    def self.broadcast_jobs_reload
      stat_job_queue = new.job_list

      TurboService.broadcast_localized_update_to(
        'admin_dashboard_jobs',
        target: 'jobs_queue_title',
        partial: 'data_cycle_core/dash_board/job_queue_title',
        locals: { stat_job_queue: }
      )
      TurboService.broadcast_localized_update_to(
        'admin_dashboard_jobs',
        target: 'jobs_queue_body',
        partial: 'data_cycle_core/dash_board/job_queue_body',
        locals: { stat_job_queue: }
      )
    end
  end
end
