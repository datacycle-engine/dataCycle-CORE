# frozen_string_literal: true

module DataCycleCore
  class ImportFullJob < ApplicationJob
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks

    queue_as :importers

    after_enqueue do |_|
      job_record = Delayed::Job.find(@provider_job_id)
      job_record.delayed_reference_id = @arguments.first
      store_job_id_to_external_source = ExternalSystem.find(job_record.delayed_reference_id)
      if store_job_id_to_external_source.config.nil?
        store_job_id_to_external_source.config = { 'last_import_full_job_id' => @provider_job_id, 'last_import_failed' => false }
      else
        store_job_id_to_external_source.config['last_import_full_job_id'] = @provider_job_id
        store_job_id_to_external_source.config['last_import_full_failed'] = false
      end
      store_job_id_to_external_source.save
      job_record.delayed_reference_type = 'import_full'
      job_record.save!
    end

    before_perform do |job|
      external_source = ExternalSystem.find(job.arguments.first)
      external_source.config['last_import_full_failed'] = false
      external_source.save!
    end

    def perform(uuid)
      external_source = ExternalSystem.find(uuid)
      pid = Process.fork do
        external_source = ExternalSystem.find(uuid)
        external_source.import({ mode: 'full' })
      rescue StandardError => e
        ActiveSupport::Notifications.instrument "#{self.class.name.demodulize.underscore}_failed.datacycle", this: {
          exception: e,
          external_system: external_source
        }
        external_source.config['last_import_full_failed'] = true
        external_source.config['last_import_full_exception'] = "#{e} (#{Time.zone.now})"
        external_source.save!
      end
      Process.waitpid(pid)

      external_source.reload
      ActiveRecord::Base.establish_connection
      raise external_source.config.dig('last_import_full_exception') if external_source.config.dig('last_import_failed')
    end
  end
end
