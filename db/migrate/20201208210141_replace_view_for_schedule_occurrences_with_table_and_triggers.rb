# frozen_string_literal: true

class ReplaceViewForScheduleOccurrencesWithTableAndTriggers < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      DROP VIEW IF EXISTS schedule_occurrences;
      
      CREATE TABLE schedule_occurrences (
      	id UUID PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
      	schedule_id UUID NOT NULL REFERENCES schedules(id) ON DELETE CASCADE,
      	thing_id UUID NOT NULL REFERENCES things(id) ON DELETE CASCADE,
      	duration INTERVAL,
      	occurrence TSTZRANGE NOT NULL
      );
      
      CREATE OR REPLACE FUNCTION generate_schedule_occurences(schedule_ids UUID[]) RETURNS UUID[] LANGUAGE PLPGSQL AS $$
      DECLARE
      	schedule_occurrence_ids UUID[];
      BEGIN
      	DELETE FROM schedule_occurrences WHERE schedule_id || '{}'::UUID[] <@ schedule_ids;
      
      	WITH occurences AS (
      		SELECT
      			schedules.id,
      		    schedules.thing_id,
              	CASE
              		WHEN duration IS NULL THEN INTERVAL '1 seconds'
              		WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
              		ELSE duration
              	END AS duration,
      		    unnest(get_occurrences(schedules.rrule::rrule, schedules.dtstart)) AS occurence
      		FROM schedules
      		WHERE schedules.relation::text = 'event_schedule'::text AND id || '{}'::UUID[] <@ schedule_ids
      		UNION
      		SELECT
      			schedules.id,
      		    schedules.thing_id,
              	CASE
              		WHEN duration IS NULL THEN INTERVAL '1 seconds'
              		WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
              		ELSE duration
              	END AS duration,
      		    unnest(schedules.rdate) AS occurence
      		FROM schedules
      		WHERE schedules.relation::text = 'event_schedule'::text AND id || '{}'::UUID[] <@ schedule_ids
      		UNION
      		SELECT
      			schedules.id,
      		    schedules.thing_id,
              	CASE
              		WHEN duration IS NULL THEN INTERVAL '1 seconds'
              		WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
              		ELSE duration
              	END AS duration,
      		    schedules.dtstart AS occurence
      		FROM schedules
      		WHERE schedules.relation::text = 'event_schedule'::text AND schedules.rrule IS NULL AND id || '{}'::UUID[] <@ schedule_ids
      	)
      	INSERT INTO schedule_occurrences (schedule_id, thing_id, duration, occurrence)
      		SELECT
      			occurences.id,
      		    occurences.thing_id,
      		    occurences.duration,
      		    tstzrange(occurences.occurence, occurences.occurence + occurences.duration) AS occurrence
      		FROM occurences
      		WHERE occurences.id || '{}'::UUID[] <@ schedule_ids;
      
      	SELECT ARRAY_AGG(id) INTO schedule_occurrence_ids
      	FROM schedule_occurrences WHERE schedule_id || '{}'::UUID[] <@ schedule_ids;
      
      	RETURN schedule_occurrence_ids;
      END;$$;
      
      CREATE OR REPLACE FUNCTION generate_schedule_occurences_trigger() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
      	PERFORM generate_schedule_occurences(NEW.id || '{}'::UUID[]);
      
      	RETURN NEW;
      END;$$;
      
      CREATE TRIGGER generate_schedule_occurences_trigger AFTER INSERT OR UPDATE ON schedules FOR EACH ROW EXECUTE FUNCTION generate_schedule_occurences_trigger();
      
      SELECT generate_schedule_occurences(ARRAY_AGG(id)) FROM schedules WHERE schedules.relation::text = 'event_schedule'::text;
    SQL
    execute('ANALYZE schedule_occurrences;')
    execute('VACUUM schedule_occurrences;')
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS generate_schedule_occurences_trigger ON schedules;
      DROP FUNCTION IF EXISTS generate_schedule_occurences_trigger;
      DROP FUNCTION IF EXISTS generate_schedule_occurences;
      DROP TABLE IF EXISTS schedule_occurrences;
    SQL
  end
end
