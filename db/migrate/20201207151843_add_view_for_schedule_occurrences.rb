# frozen_string_literal: true

class AddViewForScheduleOccurrences < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      CREATE VIEW schedule_occurrences AS (
        WITH occurrences AS (
            SELECT
            	id,
            	thing_id,
            	CASE
            		WHEN duration IS NULL THEN INTERVAL '1 seconds'
            		WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            		ELSE duration
            	END "duration",
            	UNNEST(GET_OCCURRENCES(rrule::RRULE, dtstart)) "occurrence",
            	exdate
            FROM schedules WHERE relation = 'event_schedule'
            UNION
            SELECT
            	id,
            	thing_id,
            	CASE
            		WHEN duration IS NULL THEN INTERVAL '1 seconds'
            		WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            		ELSE duration
            	END "duration",
        	    UNNEST(rdate) "occurrence",
        		exdate
            FROM schedules WHERE relation = 'event_schedule'
        ) SELECT id, thing_id, duration, TSTZRANGE(occurrence, occurrence + duration) "occurrence"
        FROM occurrences
        WHERE occurrence <> ALL(exdate));
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW IF EXISTS schedule_occurrences;
    SQL
  end
end
