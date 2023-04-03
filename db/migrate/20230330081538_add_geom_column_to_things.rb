# frozen_string_literal: true

class AddGeomColumnToThings < ActiveRecord::Migration[6.1]
  def up
    add_column :things, :geom, :geometry, srid: 4326, has_z: true

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION geom_simple_update () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN NEW.geom_simple := (
         st_simplify(
              ST_Force2D (COALESCE(NEW."geom", NEW."location", NEW.line)),
              0.00001,
              TRUE
            )
        );

      RETURN NEW;

      END;

      $$;

      DROP TRIGGER geom_simple_update_trigger ON things;

      CREATE TRIGGER geom_simple_update_trigger BEFORE
      UPDATE OF "location",
        line, "geom" ON things FOR EACH ROW
        WHEN (
          OLD."location"::TEXT IS DISTINCT
          FROM NEW."location"::TEXT
            OR OLD.line::TEXT IS DISTINCT
          FROM NEW.line::TEXT
            OR OLD."geom"::TEXT IS DISTINCT
          FROM NEW."geom"::TEXT
        ) EXECUTE PROCEDURE geom_simple_update ();
    SQL
  end

  def down
    remove_column :things, :geom

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION geom_simple_update () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN NEW.geom_simple := (
         st_simplify(
              ST_Force2D (COALESCE(NEW."location", NEW.line)),
              0.00001,
              TRUE
            )
        );

      RETURN NEW;

      END;

      $$;

      DROP TRIGGER geom_simple_update_trigger ON things;

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
end
