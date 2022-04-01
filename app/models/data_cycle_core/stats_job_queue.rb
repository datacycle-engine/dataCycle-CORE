# frozen_string_literal: true

module DataCycleCore
  class StatsJobQueue
    attr_accessor :job_list

    def update
      @job_list = []
      jobs_list = Delayed::Job.where(failed_at: nil, queue: 'importers').order(created_at: :asc)
      jobs_list.each do |job|
        next unless job.delayed_reference_id.to_s.uuid?

        if job.locked_at.nil? && job.locked_by.nil?
          @job_list.push(
            {
              'id' => job.id,
              'status' => "<span class='label secondary'>queued</span>",
              'job' => job.delayed_reference_type,
              'ref_id' => job.delayed_reference_id,
              'created_at' => job.created_at
            }
          )
        else
          @job_list.push(
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

      @job_list.push(
        {
          importers: jobs_list.count,
          cache_invalidation: Delayed::Job.where(failed_at: nil, queue: 'cache_invalidation').count,
          search_update: Delayed::Job.where(failed_at: nil, queue: 'search_update').count,
          mailers: Delayed::Job.where(failed_at: nil, queue: 'mailers').count,
          webhooks: Delayed::Job.where(failed_at: nil, queue: 'webhooks').count,
          default: Delayed::Job.where(failed_at: nil, queue: 'default').count,
          wrong_queue: Delayed::Job.where(failed_at: nil).where.not(queue: ['default', 'importers', 'cache_invalidation', 'search_update', 'mailers', 'webhooks']).count
        }
      )

      @job_list.push(
        {
          importers: Delayed::Job.where(queue: 'importers').where.not(failed_at: nil).count,
          cache_invalidation: Delayed::Job.where(queue: 'cache_invalidation').where.not(failed_at: nil).count,
          search_update: Delayed::Job.where(queue: 'search_update').where.not(failed_at: nil).count,
          mailers: Delayed::Job.where(queue: 'mailers').where.not(failed_at: nil).count,
          webhooks: Delayed::Job.where(queue: 'webhooks').where.not(failed_at: nil).count,
          default: Delayed::Job.where(queue: 'default').where.not(failed_at: nil).count,
          '*': Delayed::Job.where.not(queue: ['default', 'importers', 'cache_invalidation', 'search_update', 'mailers', 'webhooks']).where.not(failed_at: nil).count
        }
      )

      @job_list
    end
  end
end
