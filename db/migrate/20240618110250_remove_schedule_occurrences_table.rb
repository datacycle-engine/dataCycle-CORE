# frozen_string_literal: true

class RemoveScheduleOccurrencesTable < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS delete_schedule_occurences_trigger ON schedules;
      DROP TRIGGER IF EXISTS generate_schedule_occurences_trigger ON schedules;
      DROP TRIGGER IF EXISTS update_schedule_occurences_trigger ON schedules;

      DROP FUNCTION IF EXISTS generate_schedule_occurences(schedule_ids uuid []);

      DROP FUNCTION IF EXISTS delete_schedule_occurences;
      DROP FUNCTION IF EXISTS generate_schedule_occurences;
      DROP FUNCTION IF EXISTS delete_schedule_occurences_trigger;
      DROP FUNCTION IF EXISTS generate_schedule_occurences_trigger;


      DROP TABLE IF EXISTS schedule_occurrences;
    SQL
  end

  def down
    execute <<-SQL.squish
      CREATE TABLE IF NOT EXISTS schedule_occurrences (
        id uuid NOT NULL DEFAULT uuid_generate_v4(),
        schedule_id uuid NOT NULL,
        thing_id uuid NOT NULL,
        duration INTERVAL,
        occurrence tstzrange NOT NULL,
        CONSTRAINT schedule_occurrences_pkey PRIMARY KEY (id),
        CONSTRAINT schedule_occurrences_schedule_id_fkey FOREIGN KEY (schedule_id) REFERENCES schedules (id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE CASCADE,
        CONSTRAINT schedule_occurrences_thing_id_fkey FOREIGN KEY (thing_id) REFERENCES things (id) MATCH SIMPLE ON UPDATE NO ACTION ON DELETE CASCADE
      );

      CREATE INDEX IF NOT EXISTS index_occurrence ON schedule_occurrences USING gist (occurrence);

      CREATE INDEX IF NOT EXISTS index_schedule_occurrences_on_schedule_id ON schedule_occurrences USING btree (schedule_id ASC NULLS LAST);

      CREATE INDEX IF NOT EXISTS index_schedule_occurrences_on_thing_id_occurrence ON schedule_occurrences USING btree (
        thing_id ASC NULLS LAST,
        occurrence ASC NULLS LAST
      );

      CREATE OR REPLACE FUNCTION generate_schedule_occurences (schedule_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM schedule_occurrences
      WHERE schedule_id = ANY (schedule_ids);

      WITH occurences AS (
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          unnest(
            get_occurrences (
              schedules.rrule::rrule,
              schedules.dtstart AT TIME ZONE 'Europe/Vienna'
            )
          ) AT TIME ZONE 'Europe/Vienna' AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND rrule LIKE '%UNTIL%'
          AND id = ANY (schedule_ids)
        UNION
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          unnest(
            get_occurrences (
              (schedules.rrule || ';UNTIL=2037-12-31')::rrule,
              schedules.dtstart AT TIME ZONE 'Europe/Vienna'
            )
          ) AT TIME ZONE 'Europe/Vienna' AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND rrule NOT LIKE '%UNTIL%'
          AND id = ANY (schedule_ids)
        UNION
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          schedules.dtstart AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND schedules.rrule IS NULL
          AND id = ANY (schedule_ids)
        UNION
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          unnest(schedules.rdate) AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND id = ANY (schedule_ids)
      )
      INSERT INTO schedule_occurrences (
          schedule_id,
          thing_id,
          duration,
          occurrence
        )
      SELECT occurences.id,
        occurences.thing_id,
        occurences.duration,
        tstzrange(
          occurences.occurence,
          occurences.occurence + occurences.duration
        ) AS occurrence
      FROM occurences
      WHERE occurences.id = ANY (schedule_ids)
        AND NOT EXISTS (
          SELECT 1
          FROM (
              SELECT id "schedule_id",
                UNNEST(exdate) "date"
              FROM schedules
            ) "exdates"
          WHERE exdates.schedule_id = occurences.id
            AND tstzrange(
              DATE_TRUNC('day', exdates.date),
              DATE_TRUNC('day', exdates.date) + INTERVAL '1 day'
            ) && tstzrange(
              occurences.occurence,
              occurences.occurence + occurences.duration
            )
        );

      RETURN;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_schedule_occurences (schedule_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM schedule_occurrences
      WHERE schedule_id = ANY (schedule_ids);

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_schedule_occurences_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN PERFORM delete_schedule_occurences (ARRAY_AGG(id))
      FROM (
          SELECT DISTINCT old_schedules.id
          FROM old_schedules
        ) "old_schedules_alias";

      RETURN NULL;

      END;

      $BODY$;

      CREATE OR REPLACE FUNCTION generate_schedule_occurences_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN PERFORM generate_schedule_occurences(NEW.id || '{}'::UUID []);

      RETURN NEW;

      END;

      $BODY$;

      CREATE OR REPLACE TRIGGER delete_schedule_occurences_trigger
      AFTER DELETE ON schedules REFERENCING OLD TABLE AS old_schedules FOR EACH STATEMENT EXECUTE FUNCTION delete_schedule_occurences_trigger();

      CREATE OR REPLACE TRIGGER generate_schedule_occurences_trigger
      AFTER
      INSERT ON schedules FOR EACH ROW EXECUTE FUNCTION generate_schedule_occurences_trigger();

      CREATE OR REPLACE TRIGGER update_schedule_occurences_trigger
      AFTER
      UPDATE OF thing_id,
        relation,
        dtstart,
        duration,
        rrule,
        rdate,
        exdate ON schedules FOR EACH ROW
        WHEN (
          old.thing_id IS DISTINCT
          FROM new.thing_id
            OR old.duration IS DISTINCT
          FROM new.duration
            OR old.rrule::text IS DISTINCT
          FROM new.rrule::text
            OR old.dtstart IS DISTINCT
          FROM new.dtstart
            OR old.relation::text IS DISTINCT
          FROM new.relation::text
            OR old.rdate IS DISTINCT
          FROM new.rdate
            OR old.exdate IS DISTINCT
          FROM new.exdate
        ) EXECUTE FUNCTION generate_schedule_occurences_trigger();

      SELECT
        generate_schedule_occurences (ARRAY_AGG(id))
      FROM
        schedules;
    SQL
  end
end
