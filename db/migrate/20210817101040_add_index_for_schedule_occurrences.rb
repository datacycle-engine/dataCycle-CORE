# frozen_string_literal: true

class AddIndexForScheduleOccurrences < ActiveRecord::Migration[5.2]
  def up
    remove_index :schedule_occurrences, name: 'index_schedule_occurrences_on_thing_id' if index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_thing_id')
    add_index :schedule_occurrences, [:thing_id, :occurrence], name: 'index_schedule_occurrences_on_thing_id_occurrence' unless index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_thing_id_occurrence')
  end

  def down
    remove_index :schedule_occurrences, name: 'index_schedule_occurrences_on_thing_id_occurrence' if index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_thing_id_occurrence')
    add_index :schedule_occurrences, :thing_id, name: 'index_schedule_occurrences_on_thing_id' unless index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_thing_id')
  end
end
