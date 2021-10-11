# frozen_string_literal: true

namespace :dc do
  namespace :jobs do
    desc 'unlock jobs from not-running workers'
    task :unlock, [:running_job_ids] => [:environment] do |_, args|
      job_ids = args.running_job_ids

      next if job_ids.blank?

      query = Delayed::Job.where.not(locked_by: nil)

      job_ids.split('|').each do |job_id|
        query = query.where.not('delayed_jobs.locked_by ILIKE ?', "%#{job_id.squish}%")
      end

      count = query.update_all(locked_by: nil, locked_at: nil)

      puts "unlocked #{count} jobs"
    end
  end
end
