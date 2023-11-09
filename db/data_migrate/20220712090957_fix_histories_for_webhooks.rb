# frozen_string_literal: true

class FixHistoriesForWebhooks < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    # DataCycleCore::RunTaskJob.perform_later('dc:migrate:migrate_history_definitions')
  end

  def down
  end
end
