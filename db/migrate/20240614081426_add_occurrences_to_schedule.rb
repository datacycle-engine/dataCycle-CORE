# frozen_string_literal: true

class AddOccurrencesToSchedule < ActiveRecord::Migration[6.1]
  def up
    range_start, range_end = DataCycleCore.schedule_occurrences_range.values_at(:start, :end)

    range_start = range_start.call if range_start.is_a?(Proc)
    range_start = range_start.in_time_zone if range_start.is_a?(::String)
    range_start = 1.year.ago if range_start.nil?
    range_end = range_end.call if range_end.is_a?(Proc)
    range_end = range_end.in_time_zone if range_end.is_a?(::String)
    range_end = 5.years.from_now if range_end.nil?
    range_start = range_start.to_date
    range_end = range_end.to_date

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION generate_schedule_occurences_array(
          s_dtstart timestamp WITH time zone,
          s_rrule character varying,
          s_rdate timestamp WITH time zone [],
          s_exdate timestamp WITH time zone [],
          s_duration INTERVAL
        ) RETURNS tstzmultirange LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $$
      DECLARE schedule_array tstzmultirange;

      schedule_duration INTERVAL;

      all_occurrences timestamp WITHOUT time zone [];

      BEGIN CASE
        WHEN s_duration IS NULL THEN schedule_duration = INTERVAL '1 seconds';

      WHEN s_duration <= INTERVAL '0 seconds' THEN schedule_duration = INTERVAL '1 seconds';

      ELSE schedule_duration = s_duration;

      END CASE
      ;

      CASE
        WHEN s_rrule IS NULL THEN all_occurrences := ARRAY [(s_dtstart AT TIME ZONE 'Europe/Vienna')::timestamp WITHOUT time zone];

      WHEN s_rrule IS NOT NULL THEN all_occurrences := get_occurrences (
        (
          CASE
            WHEN s_rrule LIKE '%UNTIL%' THEN s_rrule
            ELSE (s_rrule || ';UNTIL=#{range_end}')
          END
        )::rrule,
        s_dtstart AT TIME ZONE 'Europe/Vienna',
        '#{range_end}' AT TIME ZONE 'Europe/Vienna'
      );

      END CASE
      ;

      WITH occurences AS (
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
      SELECT range_agg(
          tstzrange(
            occurences.occurence,
            occurences.occurence + schedule_duration
          )
        ) INTO schedule_array
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
        );

      RETURN schedule_array;

      END;

      $$;

      ALTER TABLE IF EXISTS schedules
      ADD COLUMN occurrences tstzmultirange GENERATED ALWAYS AS (
          generate_schedule_occurences_array(dtstart, rrule, rdate, exdate, duration)
        ) STORED;

      CREATE INDEX IF NOT EXISTS index_schedules_on_occurrence
        ON schedules USING gist(occurrences);
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE IF EXISTS schedules DROP COLUMN occurrences;

      DROP FUNCTION IF EXISTS generate_schedule_occurences_array(
        s_dtstart timestamp WITH time zone,
        s_rrule character varying,
        s_rdate timestamp WITH time zone [],
        s_exdate timestamp WITH time zone [],
        s_duration INTERVAL
      );
    SQL
  end
end
