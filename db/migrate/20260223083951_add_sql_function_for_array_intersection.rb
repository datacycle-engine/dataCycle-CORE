# frozen_string_literal: true

class AddSqlFunctionForArrayIntersection < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION array_intersect(anyarray, anyarray) RETURNS anyarray language SQL IMMUTABLE STRICT PARALLEL SAFE AS $FUNCTION$
      SELECT ARRAY(
          SELECT UNNEST($1)
          INTERSECT
          SELECT UNNEST($2)
        );
      $FUNCTION$;
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP FUNCTION array_intersect(anyarray, anyarray);
    SQL
  end
end
