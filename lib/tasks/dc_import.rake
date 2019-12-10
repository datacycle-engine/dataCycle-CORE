# frozen_string_literal: true

namespace :dc do
  namespace :import do
    desc 'append import and download jobs to DelayedJob Queue'
    task :append_job, [:external_source_name] => [:environment] do |_, args|
      external_source = DataCycleCore::ExternalSource.find_by!(name: args.fetch(:external_source_name))

      DataCycleCore::ImportJob.perform_later(external_source.id) unless Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download_import', delayed_reference_id: external_source.id, locked_at: nil)
    end
  end
end
