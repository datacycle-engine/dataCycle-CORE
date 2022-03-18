# frozen_string_literal: true

class TemporaryFixForScheduleOccurrencesTrigger < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION generate_schedule_occurences (
        schedule_ids uuid[]
      )
        RETURNS SETOF uuid
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM schedule_occurrences
        WHERE schedule_id = ANY (schedule_ids);
        RETURN QUERY WITH occurences AS (
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            unnest(get_occurrences (schedules.rrule::rrule, schedules.dtstart::timestamp)::timestamp with time zone[]) AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND rrule LIKE '%UNTIL%'
            AND id = ANY (schedule_ids)
          UNION
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            unnest(get_occurrences ((schedules.rrule || ';UNTIL=2037-12-31')::rrule, schedules.dtstart::timestamp)::timestamp with
        time zone[]) AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND rrule NOT LIKE '%UNTIL%'
            AND id = ANY (schedule_ids)
          UNION
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            schedules.dtstart AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND schedules.rrule IS NULL
            AND id = ANY (schedule_ids)
          UNION
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            unnest(schedules.rdate) AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND id = ANY (schedule_ids))
        INSERT INTO schedule_occurrences (
          schedule_id,
          thing_id,
          duration,
          occurrence)
        SELECT
          occurences.id,
          occurences.thing_id,
          occurences.duration,
          tstzrange(occurences.occurence, occurences.occurence + occurences.duration) AS occurrence
        FROM
          occurences
        WHERE
          occurences.id = ANY (schedule_ids)
          AND NOT EXISTS (
            SELECT
              1
            FROM (
              SELECT
                id "schedule_id",
                UNNEST(exdate) "date"
              FROM
                schedules) "exdates"
            WHERE
              exdates.schedule_id = occurences.id
        AND tstzrange(DATE_TRUNC('day', exdates.date), DATE_TRUNC('day', exdates.date) + INTERVAL
          '1 day') && tstzrange(occurences.occurence, occurences.occurence + occurences.duration))
        RETURNING
          id;
        RETURN;
      END;
      $$;
    SQL
  end

  def down
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION generate_schedule_occurences (
        schedule_ids uuid[]
      )
        RETURNS SETOF uuid
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM schedule_occurrences
        WHERE schedule_id = ANY (schedule_ids);
        RETURN QUERY WITH occurences AS (
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            unnest(get_occurrences (schedules.rrule::rrule, schedules.dtstart)) AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND rrule LIKE '%UNTIL%'
            AND id = ANY (schedule_ids)
          UNION
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            unnest(get_occurrences ((schedules.rrule || ';UNTIL=2037-12-31')::rrule, schedules.dtstart)) AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND rrule NOT LIKE '%UNTIL%'
            AND id = ANY (schedule_ids)
          UNION
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            schedules.dtstart AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND schedules.rrule IS NULL
            AND id = ANY (schedule_ids)
          UNION
          SELECT
            schedules.id,
            schedules.thing_id,
            CASE WHEN duration IS NULL THEN
              INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN
              INTERVAL '1 seconds'
            ELSE
              duration
            END AS duration,
            unnest(schedules.rdate) AS occurence
          FROM
            schedules
          WHERE
            schedules.relation IS NOT NULL
            AND id = ANY (schedule_ids))
        INSERT INTO schedule_occurrences (
          schedule_id,
          thing_id,
          duration,
          occurrence)
        SELECT
          occurences.id,
          occurences.thing_id,
          occurences.duration,
          tstzrange(occurences.occurence, occurences.occurence + occurences.duration) AS occurrence
        FROM
          occurences
        WHERE
          occurences.id = ANY (schedule_ids)
          AND NOT EXISTS (
            SELECT
              1
            FROM (
              SELECT
                id "schedule_id",
                UNNEST(exdate) "date"
              FROM
                schedules) "exdates"
            WHERE
              exdates.schedule_id = occurences.id
        AND tstzrange(DATE_TRUNC('day', exdates.date), DATE_TRUNC('day', exdates.date) + INTERVAL
          '1 day') && tstzrange(occurences.occurence, occurences.occurence + occurences.duration))
        RETURNING
          id;
        RETURN;
      END;
      $$;
    SQL
  end
end
