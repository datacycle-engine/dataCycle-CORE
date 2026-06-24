# frozen_string_literal: true

class PossiblyFixDumpAndRestoreForSchedules < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION generate_schedule_occurences_array(
          s_dtstart timestamp WITH time zone,
          s_rrule character varying,
          s_rdate timestamp WITH time zone [],
          s_exdate timestamp WITH time zone [],
          s_duration INTERVAL
        ) RETURNS tstzrange[] LANGUAGE 'plpgsql' COST 100 IMMUTABLE PARALLEL SAFE AS $BODY$

      DECLARE schedule_array tstzrange[];

      BEGIN SELECT (array_agg(x.occurrence))::tstzrange[]
        FROM public.generate_schedule_occurences(
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
      FROM public.generate_schedule_occurences(
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
    SQL
  end

  def down
  end
end
