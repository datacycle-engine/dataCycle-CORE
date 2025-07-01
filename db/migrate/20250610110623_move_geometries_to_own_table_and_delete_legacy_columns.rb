# frozen_string_literal: true

class MoveGeometriesToOwnTableAndDeleteLegacyColumns < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      INSERT INTO geometries (thing_id, relation, geom, priority)
      SELECT things.id, 'location', ST_Force3D(things.location), 3
      FROM things
      WHERE things.location IS NOT NULL;

      INSERT INTO geometries (thing_id, relation, geom, priority)
      SELECT things.id, 'line', things.line, 2
      FROM things
      WHERE things.line IS NOT NULL;

      INSERT INTO geometries (thing_id, relation, geom, priority)
      SELECT things.id, 'geom', things.geom, 1
      FROM things
      WHERE things.geom IS NOT NULL;
    SQL

    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      INSERT INTO geometry_histories (thing_history_id, relation, geom, priority)
      SELECT thing_histories.id, 'location', ST_Force3D(thing_histories.location), 2
      FROM thing_histories
      WHERE thing_histories.location IS NOT NULL;

      INSERT INTO geometry_histories (thing_history_id, relation, geom, priority)
      SELECT thing_histories.id, 'line', thing_histories.line, 1
      FROM thing_histories
      WHERE thing_histories.line IS NOT NULL;
    SQL

    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS geom_simple_insert_trigger ON public.things;
      DROP TRIGGER IF EXISTS geom_simple_update_trigger ON public.things;
      DROP FUNCTION IF EXISTS public.geom_simple_update();
    SQL

    execute <<~SQL
      ALTER TABLE things
        DROP COLUMN location CASCADE,
        DROP COLUMN line CASCADE,
        DROP COLUMN geom CASCADE,
        DROP COLUMN geom_simple CASCADE;
    SQL

    execute <<~SQL
      ALTER TABLE thing_histories
        DROP COLUMN location CASCADE,
        DROP COLUMN line CASCADE;
    SQL
  end

  def down
  end
end
