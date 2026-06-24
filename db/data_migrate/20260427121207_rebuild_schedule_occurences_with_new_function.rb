# frozen_string_literal: true

class RebuildScheduleOccurencesWithNewFunction < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('db:configure:rebuild_schedule_occurrences')
  end

  def down
  end
end
