# frozen_string_literal: true

class AddValuesForClassificationAliasPathsTransitive < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.set(queue: 'default').perform_later('db:configure:rebuild_transitive_tables')
  end

  def down
  end
end
