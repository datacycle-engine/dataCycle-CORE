# frozen_string_literal: true

class SetDefaultApiForWatchLists < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    DataCycleCore::WatchList.where(my_selection: false).update_all(api: true)
  end

  def down
  end
end
