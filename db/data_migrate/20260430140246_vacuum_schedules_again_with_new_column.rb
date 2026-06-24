# frozen_string_literal: true

class VacuumSchedulesAgainWithNewColumn < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(wait_until: Time.zone.now.change(hour: 19), queue: 'importers').perform_later('db:maintenance:vacuum', [true, 'schedules'])
  end

  def down
  end
end
