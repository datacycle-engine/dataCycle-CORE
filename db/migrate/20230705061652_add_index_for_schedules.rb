# frozen_string_literal: true

class AddIndexForSchedules < ActiveRecord::Migration[6.1]
  def change
    remove_index :schedules, :thing_id, name: 'index_schedules_on_thing_id', if_exists: true
    add_index :schedules, [:thing_id, :id, :relation], name: 'index_schedules_on_thing_id_id_relation', if_not_exists: true
  end
end
