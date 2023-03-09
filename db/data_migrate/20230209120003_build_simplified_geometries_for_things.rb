# frozen_string_literal: true

class BuildSimplifiedGeometriesForThings < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE
        things t
      SET
        geom_simple = g.geom
      FROM
        (
        SELECT
          id,
          st_simplify(ST_Force2D (COALESCE(things."location" , things.line)),
          0.00001,
          TRUE ) AS geom
        FROM
          things) g
      WHERE
        t.id = g.id;
    SQL
  end

  def down
  end
end
