# frozen_string_literal: true

require 'rake_helpers/import_helper'

namespace :dc do
  namespace :import do
    desc 'append import and download jobs to DelayedJob Queue. If run_now is true, the job will be performed immediately'
    task :append_job, [:external_source_name, :mode, :run_now] => [:environment] do |_, args|
      external_source = ImportHelper.external_system(args.fetch(:external_source_name), ['download', 'import'])

      ImportHelper.perform_job(external_source, args.fetch(:mode, nil), args.fetch(:run_now, false), DataCycleCore::ImportJob)
    end

    desc 'append import jobs to DelayedJob Queue. If run_now is true, the job will be performed immediately'
    task :append_import_job, [:external_source_name, :mode, :run_now] => [:environment] do |_, args|
      external_source = ImportHelper.external_system(args.fetch(:external_source_name), ['import'])

      ImportHelper.perform_job(external_source, args.fetch(:mode, nil), args.fetch(:run_now, false), DataCycleCore::ImportOnlyJob)
    end

    desc 'append import and download partial jobs to DelayedJob Queue'
    task :append_partial_job, [:external_source_name, :download_names, :import_names, :mode] => [:environment] do |_, args|
      abort('No download or import names provided') if args[:download_names].blank? && args[:import_names].blank?

      external_source = ImportHelper.external_system(args.fetch(:external_source_name), ['download', 'import'])

      queue = []
      args.download_names.presence&.split('|')&.each do |download_name|
        queue << DataCycleCore::DownloadPartialJob.new(external_source.id, download_name.squish.to_sym, args.mode)
      end
      args.import_names.presence&.split('|')&.each do |import_name|
        queue << DataCycleCore::ImportPartialJob.new(external_source.id, import_name.squish.to_sym, args.mode)
      end

      abort('Some jobs already exist') if queue.any? { |job| Delayed::Job.exists?(queue: job.queue_name, delayed_reference_type: job.delayed_reference_type, delayed_reference_id: job.delayed_reference_id, locked_at: nil, failed_at: nil) }

      ActiveJob.perform_all_later(queue)
    end

    desc 'append download job to the DelayedJob Queue. If run_now is true, the job will be performed immediately'
    task :append_download_job, [:external_source_name, :mode, :run_now] => [:environment] do |_, args|
      external_source = ImportHelper.external_system(args.fetch(:external_source_name), ['download'])

      ImportHelper.perform_job(external_source, args.fetch(:mode, nil), args.fetch(:run_now, false), DataCycleCore::DownloadJob)
    end

    desc 'append vacuum job to importers Queue'
    task :append_vacuum_job, [:full] => [:environment] do |_, args|
      full = args.fetch(:full, false)
      task_name = 'db:maintenance:vacuum'
      DataCycleCore::RunTaskJobImport.perform_later(task_name, full) unless Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'rake_task_importers', delayed_reference_id: task_name)
    end
  end
end
