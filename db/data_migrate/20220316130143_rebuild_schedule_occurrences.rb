# frozen_string_literal: true

class RebuildScheduleOccurrences < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'default').perform_later('dc:migrate:rebuild_schedule_occurrences')
  end

  def down
  end
end
