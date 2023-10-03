# frozen_string_literal: true

class VacuumFullThingsAgain < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(wait_until: Time.zone.now.change(hour: 19), queue: 'importers').perform_later('db:maintenance:vacuum', [true, false, 'things|thing_translations|thing_histories|thing_history_translations'])
  end

  def down
  end
end
