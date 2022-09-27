# frozen_string_literal: true

namespace :dc do
  namespace :import do
    desc 'append import and download jobs to DelayedJob Queue'
    task :append_job, [:external_source_name, :mode] => [:environment] do |_, args|
      external_source = DataCycleCore::ExternalSystem.find_by(name: args.fetch(:external_source_name))
      external_source ||= DataCycleCore::ExternalSystem.find_by!(identifier: args.fetch(:external_source_name))
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download_import', delayed_reference_id: external_source.id, locked_at: nil, failed_at: nil)
        # do nothing
      else
        DataCycleCore::ImportJob.perform_later(external_source.id, args.fetch(:mode, nil))
      end
    end

    desc 'append vacuum job to importers Queue'
    task :append_vacuum_job, [:full] => [:environment] do |_, args|
      full = args.fetch(:full, false)
      task_name = 'db:maintenance:vacuum'
      DataCycleCore::RunTaskJobImport.perform_later(task_name, full) unless Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'rake_task_importers', delayed_reference_id: task_name)
    end

    namespace :classifications do
      require 'csv'

      desc 'append vacuum job to importers Queue'
      task mappings_from_csv: :environment do
        errors = []
        pool = Concurrent::FixedThreadPool.new(ActiveRecord::Base.connection_pool.size - 1)
        futures = []

        Dir[Rails.root.join('config', 'classification_mappings', '*.csv').to_s].each do |file_path|
          CSV.foreach(file_path, encoding: 'utf-8') do |data|
            next unless data&.[](0)&.include?('>') && data&.[](1)&.include?('>')

            futures << Concurrent::Promise.execute({ executor: pool }) do
              ActiveRecord::Base.connection_pool.with_connection do
                ca = DataCycleCore::ClassificationAlias.custom_find_by_full_path(data[0])

                if ca.nil?
                  errors << "classification_alias not found (#{data[0]})"
                  print 'x'
                  next
                end

                ca.create_mapping_for_path(data[1])
                print '.'
              rescue ActiveRecord::RecordNotFound
                errors << "mapped classification_alias not found (#{data[1]})"
                print 'x'
              end
            end
          end
        end

        futures.each(&:wait!)

        puts
        puts errors.join("\n")
        puts "FINISHED IMPORTING MAPPINGS! (#{errors.size} errors)"
      end
    end
  end
end
