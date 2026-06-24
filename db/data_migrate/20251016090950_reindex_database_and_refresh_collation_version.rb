# frozen_string_literal: true

class ReindexDatabaseAndRefreshCollationVersion < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(wait_until: Time.zone.now.change(hour: 19)).perform_later('db:maintenance:refresh_collation_version')
  end

  def down
  end
end
