# frozen_string_literal: true

class AddScheduleRelatedIndexes < ActiveRecord::Migration[5.2]
  def up
    add_index :schedules, :relation, name: 'index_schedules_on_relation' unless index_name_exists?(:schedules, 'index_schedules_on_relation')
    add_index :schedule_occurrences, :thing_id, name: 'index_schedule_occurrences_on_thing_id' unless index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_thing_id')
    add_index :schedule_occurrences, :schedule_id, name: 'index_schedule_occurrences_on_schedule_id' unless index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_schedule_id')
  end

  def down
    remove_index :schedules, name: 'index_schedules_on_relation' if index_name_exists?(:schedules, 'index_schedules_on_relation')
    remove_index :schedule_occurrences, name: 'index_schedule_occurrences_on_thing_id' if index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_thing_id')
    remove_index :schedule_occurrences, name: 'index_schedule_occurrences_on_schedule_id' if index_name_exists?(:schedule_occurrences, 'index_schedule_occurrences_on_schedule_id')
  end
end
