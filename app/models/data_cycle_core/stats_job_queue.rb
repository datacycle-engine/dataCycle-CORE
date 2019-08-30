# frozen_string_literal: true

module DataCycleCore
  class StatsJobQueue
    attr_accessor :job_list

    def update
      @job_list = []
      jobs_list = Delayed::Job.where(failed_at: nil, queue: 'importers').order(created_at: :asc)
      jobs_list.each do |job|
        if job.locked_at.nil? && job.locked_by.nil?
          @job_list.push(
            {
              'status' => "<span class='label secondary'>queued</span>",
              'job' => job.delayed_reference_type,
              'ref_id' => job.delayed_reference_id,
              'created_at' => job.created_at
            }
          )
        else
          @job_list.push(
            {
              'status' => "<span class='label success'>running</span>",
              'job' => job.delayed_reference_type,
              'ref_id' => job.delayed_reference_id,
              'created_at' => job.created_at.time
            }
          )
        end
      end
      @job_list.push(
        {
          importers: jobs_list.count,
          carrierwave: Delayed::Job.where(failed_at: nil, queue: 'carrierwave').count,
          cache_invalidation: Delayed::Job.where(failed_at: nil, queue: 'cache_invalidation').count,
          search_update: Delayed::Job.where(failed_at: nil, queue: 'search_update').count,
          mailer: Delayed::Job.where(failed_at: nil, queue: 'mailer').count,
          '*': Delayed::Job.where(failed_at: nil).where.not(queue: ['importers', 'carrierwave', 'cache_invalidation', 'search_update', 'mailer']).count
        }
      )
      @job_list
    end
  end
end
