# frozen_string_literal: true

class AddTriggerForSchedulesDelete < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION delete_schedule_occurences (
        schedule_ids uuid[]
      )
        RETURNS void
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM schedule_occurrences
        WHERE schedule_id = ANY (schedule_ids);
      END;
      $$;

      CREATE OR REPLACE FUNCTION delete_schedule_occurences_trigger ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          delete_schedule_occurences (ARRAY_AGG(id))
        FROM ( SELECT DISTINCT
            old_schedules.id
          FROM
            old_schedules) "old_schedules_alias";
        RETURN NULL;
      END;
      $$;

      CREATE TRIGGER delete_schedule_occurences_trigger
        AFTER DELETE ON schedules REFERENCING OLD TABLE AS old_schedules
        FOR EACH STATEMENT
        EXECUTE FUNCTION delete_schedule_occurences_trigger ();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS delete_schedule_occurences_trigger ON schedules;
      DROP FUNCTION IF EXISTS delete_schedule_occurences_trigger;
      DROP FUNCTION IF EXISTS delete_schedule_occurences;
    SQL
  end
end
