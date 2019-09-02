# frozen_string_literal: true

module DataCycleCore
  class DownloadJob < ApplicationJob
    # there is a bug in ActiveJob in combination with DelayedJob that prevents
    # @provider_job_id to be available in the perform actions and callbacks!!
    # it is available in the enque-callbacks

    queue_as :importers

    after_enqueue do |_|
      job_record = Delayed::Job.find(@provider_job_id)
      job_record.delayed_reference_id = @arguments.first
      store_job_id_to_external_source = ExternalSource.find(job_record.delayed_reference_id)
      if store_job_id_to_external_source.config.nil?
        store_job_id_to_external_source.config = { 'last_download_job_id' => @provider_job_id }
      else
        store_job_id_to_external_source.config['last_download_job_id'] = @provider_job_id
      end
      store_job_id_to_external_source.save
      job_record.delayed_reference_type = 'download'
      job_record.save!
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
