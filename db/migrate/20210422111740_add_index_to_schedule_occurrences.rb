# frozen_string_literal: true

class AddIndexToScheduleOccurrences < ActiveRecord::Migration[5.2]
  def change
    add_index :schedule_occurrences, :occurrence, name: 'index_occurrence', using: 'gist'
  end
end
