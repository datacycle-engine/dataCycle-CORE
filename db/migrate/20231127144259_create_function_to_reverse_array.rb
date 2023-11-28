# frozen_string_literal: true

class CreateFunctionToReverseArray < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION array_reverse(anyarray) RETURNS anyarray AS $$
      SELECT ARRAY(
          SELECT $1 [i]
          FROM generate_subscripts($1, 1) AS s(i)
          ORDER BY i DESC
        );

      $$ LANGUAGE 'sql' STRICT IMMUTABLE;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS array_reverse;
    SQL
  end
end
