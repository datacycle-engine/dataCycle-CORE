# frozen_string_literal: true

class AddIndexSchedule < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      CREATE INDEX IF NOT EXISTS index_schedules_on_from_to ON schedules USING GIST (tstzrange(dtstart::timestamp with time zone, dtend::timestamp with time zone, '[]'));
      CREATE INDEX IF NOT EXISTS index_schedule_histories_on_from_to ON schedule_histories USING GIST (tstzrange(dtstart::timestamp with time zone, dtend::timestamp with time zone, '[]'));
    SQL
    add_index :schedules, :thing_id
    add_index :schedule_histories, :thing_history_id
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS index_schedules_on_from_to;
      DROP INDEX IF EXISTS index_schedule_histories_on_from_to;
    SQL
    remove_index :schedules, :thing_id
    remove_index :schedule_histories, :thing_history_id
  end
end
