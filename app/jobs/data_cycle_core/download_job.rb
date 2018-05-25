module DataCycleCore
  class DownloadJob < ApplicationJob
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks

    queue_as :default

    after_enqueue do |_|
      job_record = Delayed::Job.find(@provider_job_id)
      job_record.delayed_reference_id = @arguments.first
      store_job_id_to_externalSource = ExternalSource.find(job_record.delayed_reference_id)
      if store_job_id_to_externalSource.config.nil?
        store_job_id_to_externalSource.config = { 'last_download_job_id' => @provider_job_id }
      else
        store_job_id_to_externalSource.config['last_download_job_id'] = @provider_job_id
      end
      store_job_id_to_externalSource.save
      job_record.delayed_reference_type = store_job_id_to_externalSource.config['download']
      job_record.save!
    end

    around_perform do |_, block|
      # Do something before perform
      block.call
      # Do something after perform
      
      uuid = @arguments.first
      external_source = ExternalSource.find(uuid)
      job_record_id = external_source.config['last_download_job_id']
      job_record = Delayed::Job.find(job_record_id)
      if job_record.present? && job_record.failed_at.blank?
        external_source.last_download = Time.zone.now
        external_source.save
      end
    end

    def perform(uuid)
      pid = Process.fork do
        ExternalSource.find(uuid).download
      end
      Process.waitpid(pid)

      ActiveRecord::Base.establish_connection
    end
  end
end
