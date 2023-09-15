# frozen_string_literal: true

module DataCycleCore
  class StatsJobQueue
    attr_accessor :job_list

    def update
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

      @job_list[:queued] = Delayed::Job.where(failed_at: nil, locked_at: nil, locked_by: nil).group(:queue).count
      @job_list[:running] = Delayed::Job.where(failed_at: nil).where.not(locked_at: nil).group(:queue).count
      @job_list[:failed] = Delayed::Job.where.not(failed_at: nil).group(:queue).count

      @job_list
    end
  end
end
