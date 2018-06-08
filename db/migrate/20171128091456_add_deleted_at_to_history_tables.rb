# frozen_string_literal: true

class AddDeletedAtToHistoryTables < ActiveRecord::Migration[5.0]
  def up
    add_column :creative_work_histories, :deleted_at, :datetime
    add_column :event_histories, :deleted_at, :datetime
    add_column :place_histories, :deleted_at, :datetime
    add_column :person_histories, :deleted_at, :datetime
  end

  def down
    remove_column :creative_work_histories, :deleted_at
    remove_column :event_histories, :deleted_at
    remove_column :place_histories, :deleted_at
    remove_column :person_histories, :deleted_at
  end
end
