# frozen_string_literal: true

class AddColumnAndTriggerForSimplifiedGeometries < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    add_column :things, :geom_simple, :geometry, srid: 4326
    add_index :things, :geom_simple, name: 'index_things_on_geom_simple_spatial', using: :gist

    execute('VACUUM ANALYZE things')

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION geom_simple_update () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN NEW.geom_simple := (
          SELECT st_simplify(
              ST_Force2D (COALESCE(NEW."location", NEW.line)),
              0.00001,
              TRUE
            )
          FROM things
          WHERE things.id = NEW.id
        );

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER geom_simple_insert_trigger BEFORE
      INSERT ON things FOR EACH ROW EXECUTE PROCEDURE geom_simple_update ();

      CREATE TRIGGER geom_simple_update_trigger BEFORE
      UPDATE OF "location",
        line ON things FOR EACH ROW
        WHEN (
          OLD."location"::TEXT IS DISTINCT
          FROM NEW."location"::TEXT
            OR OLD.line::TEXT IS DISTINCT
          FROM NEW.line::TEXT
        ) EXECUTE PROCEDURE geom_simple_update ();
    SQL
  end

  def down
    remove_index :things, name: 'index_things_on_geom_simple_spatial'
    remove_column :things, :geom_simple

    execute <<-SQL.squish
      DROP TRIGGER geom_simple_update_trigger ON things;
      DROP TRIGGER geom_simple_insert_trigger ON things;
      DROP FUNCTION geom_simple_update;
    SQL
  end
end
