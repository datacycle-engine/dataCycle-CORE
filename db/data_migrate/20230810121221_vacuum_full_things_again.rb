# frozen_string_literal: true

class VacuumFullThingsAgain < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'importers').perform_later('db:maintenance:vacuum', [true, false, 'things|thing_histories'])
  end

  def down
  end
end
