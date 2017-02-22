class StatsJobQueue
  attr_accessor :job_list

  def update
    @job_list = []
    jobs_list = Delayed::Job.where(failed_at: nil, queue: "default").order(created_at: :asc)
    jobs_list.each do |job|
      if job.locked_at.nil? && job.locked_by.nil?
        @job_list.push({
          "status" => "<i class='material-icons'>timer</i> <span class='label secondary'>queued</span>",
          "job" => job.delayed_reference_type,
          "ref_id" => job.delayed_reference_id,
          "created_at" => job.created_at
          })
      else
        @job_list.push({
          "status" => "<i class='material-icons'>file_download</i> <span class='label success'>running</span>",
          "job" => job.delayed_reference_type,
          "ref_id" => job.delayed_reference_id,
          "created_at" => job.created_at.time
          })
      end
    end
    @job_list
  end

end
