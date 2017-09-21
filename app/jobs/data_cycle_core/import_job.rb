module DataCycleCore
  class ImportJob < ActiveJob::Base
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks

    queue_as :default

    after_enqueue do |job|
      job_record = Delayed::Job.where(id: @provider_job_id).first
      job_record.delayed_reference_id = @arguments.first
      store_job_id_to_externalSource = ExternalSource.where(id: job_record.delayed_reference_id).first
      if store_job_id_to_externalSource.config.nil?
        store_job_id_to_externalSource.config = {"last_import_job_id" => @provider_job_id}
      else
        store_job_id_to_externalSource.config.merge!({"last_import_job_id" => @provider_job_id})
      end
      store_job_id_to_externalSource.save
      job_record.delayed_reference_type = store_job_id_to_externalSource.config['import']
      job_record.save!
    end

    around_perform do |job, block|
      # Do something before perform
      block.call
      # Do something after perform
      uuid = @arguments.first
      external_source = ExternalSource.where(id: uuid).first
      job_record_id = external_source.config["last_import_job_id"]
      job_record = Delayed::Job.where(id: job_record_id).first
      if !job_record.nil? && job_record.failed_at.nil?
        external_source.last_import = Time.zone.now
        external_source.save
      end
    end

    def perform(uuid)
      ExternalSource.find(uuid).import
    end
  end
end
