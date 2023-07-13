# frozen_string_literal: true

class RebuildCccRelations < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('db:configure:rebuild_ccc_relations')
  end

  def down
  end
end
