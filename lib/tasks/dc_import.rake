# frozen_string_literal: true

namespace :dc do
  namespace :import do
    desc 'append import and download jobs to DelayedJob Queue'
    task :append_job, [:external_source_name, :mode] => [:environment] do |_, args|
      external_source = DataCycleCore::ExternalSystem.find_by(name: args.fetch(:external_source_name))
      external_source ||= DataCycleCore::ExternalSystem.find_by!(identifier: args.fetch(:external_source_name))
      DataCycleCore::ImportJob.perform_later(external_source.id, args.fetch(:mode, nil)) unless Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download_import', delayed_reference_id: external_source.id, locked_at: nil)
    end

    desc 'append vacuum job to importers Queue'
    task :append_vacuum_job, [:full] => [:environment] do |_, args|
      full = args.fetch(:full, false)
      task_name = 'db:maintenance:vacuum'
      DataCycleCore::RunTaskJobImport.perform_later(task_name, full) unless Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'rake_task_importers', delayed_reference_id: task_name)
    end
  end
end
