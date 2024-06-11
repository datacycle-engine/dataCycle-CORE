# frozen_string_literal: true

namespace :dc do
  namespace :jobs do
    desc 'unlock jobs from not-running workers'
    task unlock: :environment do
      jobs_to_unlock = Delayed::Job.where.not(locked_by: nil).where(failed_at: nil)
      count = jobs_to_unlock.update_all(locked_by: nil, locked_at: nil)

      puts "unlocked #{count} jobs"
    end
  end
end
