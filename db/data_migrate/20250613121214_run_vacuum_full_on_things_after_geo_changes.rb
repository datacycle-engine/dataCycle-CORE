# frozen_string_literal: true

class RunVacuumFullOnThingsAfterGeoChanges < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(wait_until: Time.zone.now.change(hour: 19), queue: 'importers').perform_later('db:maintenance:vacuum', [true, 'things|thing_histories'])
  end

  def down
  end
end
