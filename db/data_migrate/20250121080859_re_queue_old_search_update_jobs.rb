# frozen_string_literal: true

class ReQueueOldSearchUpdateJobs < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    jobs = Delayed::Job.where(queue: 'search_update', delayed_reference_type: 'DataCycleCore::Thing')
    thing_ids = jobs.map do |job|
      job.payload_object.job_data.dig('arguments', 1)
    rescue StandardError
      nil
    end

    DataCycleCore::Thing.where(id: thing_ids.compact.uniq).find_each do |thing|
      thing.search_languages(true)
    end

    jobs.delete_all
  end

  def down
  end
end
