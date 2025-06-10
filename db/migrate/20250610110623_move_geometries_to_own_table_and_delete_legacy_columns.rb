# frozen_string_literal: true

class MoveGeometriesToOwnTableAndDeleteLegacyColumns < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      INSERT INTO geometries (thing_id, relation, geom)
      SELECT id, 'location', ST_Force3D(location)
      FROM things
      WHERE location IS NOT NULL;

      INSERT INTO geometries (thing_id, relation, geom)
      SELECT id, 'line', line
      FROM things
      WHERE line IS NOT NULL;

      INSERT INTO geometries (thing_id, relation, geom)
      SELECT id, 'geom', geom
      FROM things
      WHERE geom IS NOT NULL;
    SQL

    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      INSERT INTO geometry_histories (thing_history_id, relation, geom)
      SELECT id, 'location', ST_Force3D(location)
      FROM thing_histories
      WHERE location IS NOT NULL;

      INSERT INTO geometry_histories (thing_history_id, relation, geom)
      SELECT id, 'line', line
      FROM thing_histories
      WHERE line IS NOT NULL;
    SQL

    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS geom_simple_insert_trigger ON public.things;
      DROP TRIGGER IF EXISTS geom_simple_update_trigger ON public.things;
      DROP FUNCTION IF EXISTS public.geom_simple_update();
    SQL

    change_table :things, bulk: true do |t|
      t.remove :location, :line, :geom, :geom_simple
    end

    change_table :thing_histories, bulk: true do |t|
      t.remove :location, :line
    end
  end

  def down
  end
end
