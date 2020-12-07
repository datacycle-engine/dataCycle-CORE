# frozen_string_literal: true

class AddViewForScheduleOccurrences < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      CREATE VIEW schedule_occurrences AS (
      WITH occurences AS (
          SELECT id, thing_id, COALESCE(duration, INTERVAL '0 seconds') "duration", UNNEST(GET_OCCURRENCES(rrule::RRULE, dtstart)) "occurence"
          FROM schedules WHERE relation = 'event_schedule'
          UNION
          SELECT id, thing_id, COALESCE(duration, INTERVAL '0 seconds') "duration", UNNEST(rdate) "occurence"
          FROM schedules WHERE relation = 'event_schedule'
      ) SELECT id, thing_id, duration, TSTZRANGE(occurence, occurence + duration) "occurrence"
      FROM occurences);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW IF EXISTS schedule_occurrences;
    SQL
  end
end
