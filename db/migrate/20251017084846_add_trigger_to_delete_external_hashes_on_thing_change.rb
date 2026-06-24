# frozen_string_literal: true

class AddTriggerToDeleteExternalHashesOnThingChange < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE TRIGGER delete_things_external_source_trigger BEFORE
      UPDATE OF external_source_id,
        external_key ON public.things FOR EACH ROW
        WHEN (
          old.external_key::text IS DISTINCT
          FROM new.external_key::text
            OR old.external_source_id IS DISTINCT
          FROM new.external_source_id
        ) EXECUTE FUNCTION public.delete_things_external_source_trigger_function();
    SQL
  end

  def down
  end
end
