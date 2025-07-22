# frozen_string_literal: true

class AddTriggerToInvalidateThingsCacheAfterMappings < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.invalidate_things_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' AS $$ BEGIN
      UPDATE things
      SET cache_valid_since = NOW()
      WHERE things.id IN (
          SELECT id
          FROM things
          WHERE things.id IN (
              SELECT updated_ccc.thing_id
              FROM updated_ccc
              WHERE updated_ccc.link_type != 'broader'
            ) FOR
          UPDATE SKIP LOCKED
        );

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE TRIGGER update_invalidate_things_trigger
      AFTER
      UPDATE ON public.collected_classification_contents REFERENCING NEW TABLE AS updated_ccc FOR EACH STATEMENT EXECUTE FUNCTION public.invalidate_things_trigger();

      CREATE OR REPLACE TRIGGER insert_invalidate_things_trigger
      AFTER
      INSERT ON public.collected_classification_contents REFERENCING NEW TABLE AS updated_ccc FOR EACH STATEMENT EXECUTE FUNCTION public.invalidate_things_trigger();

      CREATE OR REPLACE TRIGGER delete_invalidate_things_trigger
      AFTER DELETE ON public.collected_classification_contents REFERENCING OLD TABLE AS updated_ccc FOR EACH STATEMENT EXECUTE FUNCTION public.invalidate_things_trigger();
    SQL
  end

  def down
  end
end
