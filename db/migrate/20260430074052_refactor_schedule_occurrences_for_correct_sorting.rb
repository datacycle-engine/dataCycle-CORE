# frozen_string_literal: true

class RefactorScheduleOccurrencesForCorrectSorting < ActiveRecord::Migration[8.0]
  def up
    range_start = 1.year.ago.to_date
    range_end = 5.years.from_now.to_date

    execute <<~SQL.squish
      SET LOCAL statement_timeout = 0;

      CREATE OR REPLACE FUNCTION generate_schedule_occurences(
          s_dtstart timestamp WITH time zone,
          s_rrule character varying,
          s_rdate timestamp WITH time zone [],
          s_exdate timestamp WITH time zone [],
          s_duration INTERVAL
        ) RETURNS setof tstzrange LANGUAGE 'plpgsql' COST 100 IMMUTABLE PARALLEL SAFE AS $BODY$
      DECLARE schedule_duration INTERVAL;

      all_occurrences timestamp WITHOUT time zone [];

      BEGIN IF s_dtstart > '#{range_end}' THEN RETURN;

      END IF;

      CASE
        WHEN s_duration IS NULL THEN schedule_duration = INTERVAL '1 seconds';

      WHEN s_duration <= INTERVAL '0 seconds' THEN schedule_duration = INTERVAL '1 seconds';

      ELSE schedule_duration = s_duration;

      END CASE
      ;

      CASE
        WHEN s_rrule IS NULL THEN all_occurrences := ARRAY [(s_dtstart AT TIME ZONE 'Europe/Vienna')::timestamp WITHOUT time zone];

      WHEN s_rrule IS NOT NULL THEN all_occurrences := public.get_occurrences (
        (
          CASE
            WHEN s_rrule LIKE '%UNTIL%' THEN s_rrule
            ELSE (s_rrule || ';UNTIL=#{range_end}')
          END
        )::public.rrule,
        s_dtstart AT TIME ZONE 'Europe/Vienna',
        '#{range_end}' AT TIME ZONE 'Europe/Vienna'
      );

      END CASE
      ;

      RETURN QUERY WITH occurences AS (
        SELECT unnest(all_occurrences) AT TIME ZONE 'Europe/Vienna' AS occurence
        UNION
        SELECT unnest(s_rdate) AS occurence
      ),
      exdates AS (
        SELECT tstzrange(
            DATE_TRUNC('day', s.exdate),
            DATE_TRUNC('day', s.exdate) + INTERVAL '1 day'
          ) exdate
        FROM unnest(s_exdate) AS s(exdate)
      )
      SELECT tstzrange(
            occurences.occurence,
            occurences.occurence + schedule_duration
            )
      FROM occurences
      WHERE occurences.occurence IS NOT NULL
        AND occurences.occurence + schedule_duration > '#{range_start}'
        AND NOT EXISTS (
          SELECT 1
          FROM exdates
          WHERE exdates.exdate && tstzrange(
              occurences.occurence,
              occurences.occurence + schedule_duration
            )
        )
      ORDER BY occurences.occurence ASC;

      END;

      $BODY$;

      ALTER TABLE schedules DROP COLUMN IF EXISTS occurrences;

      DROP FUNCTION IF EXISTS generate_schedule_occurences_array(
          timestamp WITH time zone,
          character varying,
          timestamp WITH time zone [],
          timestamp WITH time zone [],
          INTERVAL
        );

      CREATE OR REPLACE FUNCTION generate_schedule_occurences_array(
          s_dtstart timestamp WITH time zone,
          s_rrule character varying,
          s_rdate timestamp WITH time zone [],
          s_exdate timestamp WITH time zone [],
          s_duration INTERVAL
        ) RETURNS tstzrange[] LANGUAGE 'plpgsql' COST 100 IMMUTABLE PARALLEL SAFE AS $BODY$

      DECLARE schedule_array tstzrange[];

      BEGIN SELECT (array_agg(x.occurrence))::tstzrange[]
        FROM generate_schedule_occurences(
          s_dtstart,
          s_rrule,
          s_rdate,
          s_exdate,
          s_duration
        ) AS x(occurrence)
        INTO schedule_array;

      RETURN schedule_array;

      END;

      $BODY$;

      CREATE OR REPLACE FUNCTION generate_schedule_occurences_multirange(
          s_dtstart timestamp WITH time zone,
          s_rrule character varying,
          s_rdate timestamp WITH time zone [],
          s_exdate timestamp WITH time zone [],
          s_duration INTERVAL
        ) RETURNS tstzmultirange LANGUAGE 'plpgsql' COST 100 IMMUTABLE PARALLEL SAFE AS $BODY$

      DECLARE schedule_array tstzmultirange;

      BEGIN SELECT (range_agg(x.occurrence))::tstzmultirange
      FROM generate_schedule_occurences(
          s_dtstart,
          s_rrule,
          s_rdate,
          s_exdate,
          s_duration
        ) AS x(occurrence)
      INTO schedule_array;

      RETURN schedule_array;

      END;

      $BODY$;

      ALTER TABLE schedules
      ADD COLUMN IF NOT EXISTS occurrences tstzmultirange
      GENERATED ALWAYS AS (generate_schedule_occurences_multirange(dtstart, rrule, rdate, exdate, duration)) STORED;

      ALTER TABLE schedules
      ADD COLUMN IF NOT EXISTS occurrences_array tstzrange[]
      GENERATED ALWAYS AS (generate_schedule_occurences_array(dtstart, rrule, rdate, exdate, duration)) STORED;
    SQL

    execute <<~SQL.squish
      CREATE INDEX IF NOT EXISTS index_schedules_on_occurrences_array
      ON schedules USING GIN (occurrences_array);

      CREATE INDEX IF NOT EXISTS index_schedules_on_occurrences
      ON schedules USING GIST (occurrences);
    SQL
  end

  def down
  end
end
