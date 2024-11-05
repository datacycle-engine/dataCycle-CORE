# frozen_string_literal: true

class ClearCacheForNewFormat < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:cache:clear_rails_cache')
  end

  def down
  end
end
