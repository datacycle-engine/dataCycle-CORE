# frozen_string_literal: true

namespace :data_cycle_core do
  namespace :export do
    desc 'List available endpoints for import'
    task list: :environment do
      DataCycleCore::ExternalSystem.all.each do |external_system|
        puts "#{external_system.id} - #{external_system.name}"
      end
    end

    desc 'refresh tasks'
    task :refresh, [:external_system_id, :job_id] => [:environment] do |_, args|
      external_system = DataCycleCore::ExternalSystem.find(args[:external_system_id])
      external_system.refresh({ job_id: args.fetch(:job_id, nil) })
    end
  end
end
