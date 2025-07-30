# frozen_string_literal: true

class AddTriggerToGeometriesToMakeValid < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION make_valid_geometries() RETURNS TRIGGER AS $$
      BEGIN
        NEW.geom = ST_MakeValid(NEW.geom);
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER make_valid_geometries_trigger
      BEFORE INSERT OR UPDATE OF geom ON geometries
      FOR EACH ROW EXECUTE FUNCTION make_valid_geometries();

      CREATE TRIGGER make_valid_classification_polygons_trigger
      BEFORE INSERT OR UPDATE OF geom ON classification_polygons
      FOR EACH ROW EXECUTE FUNCTION make_valid_geometries();
    SQL
  end

  def down
  end
end
