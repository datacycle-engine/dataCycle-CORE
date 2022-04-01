# frozen_string_literal: true

class FixSchedulesForValiditySchedules < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'default').perform_later('dc:migrate:remove_multiple_byyearday')
  end

  def down
  end
end
