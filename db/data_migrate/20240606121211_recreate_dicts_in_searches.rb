# frozen_string_literal: true

class RecreateDictsInSearches < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::RunTaskJob.perform_later('dc:search:recreate_dicts')
  end

  def down
  end
end
