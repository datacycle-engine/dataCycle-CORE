# frozen_string_literal: true

class RefactorUpdateGeoPrioritiesByThingIdTrigger < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.update_things_geo_priorities_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $BODY$ BEGIN PERFORM update_geo_priorities_by_thing_id(ARRAY [NEW.id]::UUID []);

      RETURN NULL;

      END;

      $BODY$;

      DROP TRIGGER IF EXISTS update_things_geo_priorities_trigger ON public.things;

      CREATE OR REPLACE TRIGGER update_things_geo_priorities_trigger
      AFTER
      UPDATE OF template_name ON public.things FOR EACH ROW
        WHEN (
          OLD.template_name::text IS DISTINCT
          FROM NEW.template_name::text
        ) EXECUTE FUNCTION public.update_things_geo_priorities_trigger();
    SQL
  end

  def down
  end
end
