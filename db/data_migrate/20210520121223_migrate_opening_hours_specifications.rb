# frozen_string_literal: true

class MigrateOpeningHoursSpecifications < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:migrate:migrate_opening_hours')
  end

  def down
  end
end
