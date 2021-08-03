# frozen_string_literal: true

class MigrateFeratelOrtlichkeiten < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:migrate:ortlichkeit_to_poi')
  end

  def down
  end
end
