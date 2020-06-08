# frozen_string_literal: true

class AddExternalKeyColumnForHistoryTables < ActiveRecord::Migration[5.0]
  def up
    add_column :creative_work_histories, :external_key, :string

    add_column :person_histories, :external_key, :string

    add_column :event_histories, :external_key, :string
  end

  def down
    remove_column :creative_work_histories, :external_key

    remove_column :person_histories, :external_key

    remove_column :event_histories, :external_key
  end
end
