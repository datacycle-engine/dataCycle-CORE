# frozen_string_literal: true

class RebuildSearch < ActiveRecord::Migration[5.2]
  def up
    return if Rails.env.test?

    task = 'dc:update:search:rebuild'
    return if Delayed::Job.exists?(queue: 'search_update', delayed_reference_type: task, delayed_reference_id: task, locked_at: nil)
    Delayed::Job.enqueue(
      payload_object: DataCycleCore::Jobs::RunTaskJob.new(task, []),
      run_at: 1.hour.from_now,
      queue: 'search_update'
    )
  end

  def down
  end
end
