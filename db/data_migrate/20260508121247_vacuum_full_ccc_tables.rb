# frozen_string_literal: true

class VacuumFullCccTables < ActiveRecord::Migration[8.0]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return say('the pre-concept classification tables are gone (see #41458); nothing to migrate') unless table_exists?(:classification_aliases)

    DataCycleCore::RunTaskJob.set(wait_until: Time.zone.now.change(hour: 19), queue: 'importers')
      .perform_later('db:maintenance:vacuum', [true, 'collected_classification_contents'])
  end

  def down
  end
end
