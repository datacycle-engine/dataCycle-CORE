# frozen_string_literal: true

class MergeDuplicateSystemClassifications < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_now('dc:concepts:merge_system_duplicates')
  end

  def down
  end
end
