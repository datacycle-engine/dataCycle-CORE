# frozen_string_literal: true

namespace :dc do
  namespace :jobs do
    desc 'requeue jobs left behind by workers that did not shut down cleanly'
    task unlock: :environment do
      unless DataCycleCore::JobRecovery.tables_exist?
        puts 'skipping: the job tables do not exist yet'
        next
      end

      DataCycleCore::JobRecovery.unlock.each do |step, count|
        puts "#{step.to_s.humanize}: #{count}"
      end
    end

    desc 'validate that every job queue is served by a worker in config/queue.yml'
    task validate: :environment do
      puts "validating job queue configuration\n"
      errors = DataCycleCore::JobQueueValidation.new.errors

      if errors.blank?
        puts(AmazingPrint::Colors.green('[✔] ... looks good 🚀'))
      else
        puts AmazingPrint::Colors.red('🔥 the following errors were encountered during validation:')
        ap errors
        exit(-1)
      end
    end
  end
end
