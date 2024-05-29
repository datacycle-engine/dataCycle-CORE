# frozen_string_literal: true

namespace :dc do
  namespace :import do
    desc 'append import and download jobs to DelayedJob Queue. If run_now is true, the job will be performed immediately'
    task :append_job, [:external_source_name, :mode, :run_now] => [:environment] do |_, args|
      external_source = DataCycleCore::ExternalSystem.find_by(name: args.fetch(:external_source_name))
      external_source ||= DataCycleCore::ExternalSystem.find_by!(identifier: args.fetch(:external_source_name))

      run_now = args.fetch(:run_now, false) == 'true' || args.fetch(:run_now, false) == true
      binding.pry
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download_import', delayed_reference_id: external_source.id, locked_at: nil, failed_at: nil)
        # do nothing
      elsif run_now
        DataCycleCore::DownloadJob.perform_now(external_source.id)
        DataCycleCore::ImportJob.perform_now(external_source.id, args.fetch(:mode, nil))
      else
        DataCycleCore::DownloadJob.perform_later(external_source.id)
        DataCycleCore::ImportJob.perform_later(external_source.id, args.fetch(:mode, nil))
      end
    end

    desc 'append import and download partial jobs to DelayedJob Queue'
    task :append_partial_job, [:external_source_name, :download_names, :import_names, :mode] => [:environment] do |_, args|
      external_source = DataCycleCore::ExternalSystem.find_by(name: args.fetch(:external_source_name))
      external_source ||= DataCycleCore::ExternalSystem.find_by!(identifier: args.fetch(:external_source_name))

      if args[:download_names].blank? && args[:import_names].blank?
        puts 'No download or import names provided. Exiting...'
        exit(-1)
      end

      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: "download_#{args[:download_names]}", delayed_reference_id: external_source.id, locked_at: nil, failed_at: nil) ||
         Delayed::Job.exists?(queue: 'importers', delayed_reference_type: "import_#{args[:download_names]}", delayed_reference_id: external_source.id, locked_at: nil, failed_at: nil)
        # do nothing
      else
        args[:download_names].presence.split(',').each do |download_name|
          DataCycleCore::DownloadPartialJob.perform_later(external_source.id, download_name.squish.to_sym, args.fetch(:mode, nil))
        end
        args[:import_names].presence.split(',').each do |import_name|
          DataCycleCore::ImportPartialJob.perform_later(external_source.id, import_name.squish.to_sym, args.fetch(:mode, nil))
        end
      end
    end

    desc 'append vacuum job to importers Queue'
    task :append_vacuum_job, [:full] => [:environment] do |_, args|
      full = args.fetch(:full, false)
      task_name = 'db:maintenance:vacuum'
      DataCycleCore::RunTaskJobImport.perform_later(task_name, full) unless Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'rake_task_importers', delayed_reference_id: task_name)
    end
  end
end
