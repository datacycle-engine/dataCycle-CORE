# frozen_string_literal: true

class UpdateTriggerForSimplifiedGeometries < ActiveRecord::Migration[6.1]
  def up
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
    SQL
  end

  def down
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
    SQL
  end
end
