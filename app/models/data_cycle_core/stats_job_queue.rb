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
      jobs_list = Delayed::Job.where(failed_at: nil, queue: 'importers').order(created_at: :asc)
      jobs_list.each do |job|
        next unless job.delayed_reference_id.to_s.uuid?

        if job.locked_at.nil? && job.locked_by.nil?
          @job_list[:importers].push(
            {
              'id' => job.id,
              'status' => "<span class='label secondary'>queued</span>",
              'job' => job.delayed_reference_type,
              'ref_id' => job.delayed_reference_id,
              'created_at' => job.created_at
            }
          )
        else
          @job_list[:importers].push(
            {
              'id' => job.id,
              'status' => "<span class='label success'>running</span>",
              'job' => job.delayed_reference_type,
              'ref_id' => job.delayed_reference_id,
              'created_at' => job.created_at.time
            }
          )
        end
      end

      data = self.class.all.to_a

      @job_list[:queued] = data.filter(&:queued).pluck(:queue_name, :queued).to_h
      @job_list[:running] = data.filter(&:running).pluck(:queue_name, :running).to_h
      @job_list[:failed] = data.filter(&:failed).pluck(:queue_name, :failed).to_h
      @job_list[:delayed_reference_types] = data.to_h { |d| [d.queue_name, d.attributes.slice('queued_types', 'running_types', 'failed_types')] }
      @job_list[:rebuild_classification_mappings] = data.any? { |d| d.queue_name == DataCycleCore::RebuildClassificationMappingsJob.queue_as && DataCycleCore::RebuildClassificationMappingsJob::REFERENCE_TYPE.in?(d.runnable_types) }

      @job_list
    end
  end
end
