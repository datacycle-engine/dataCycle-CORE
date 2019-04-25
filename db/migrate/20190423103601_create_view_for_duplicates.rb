# frozen_string_literal: true

class CreateViewForDuplicates < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL.squish
      CREATE VIEW duplicate_candidates AS
      SELECT thing_duplicates.thing_duplicate_id AS duplicate_id, thing_duplicates.thing_id AS original_id, thing_duplicates.score
      FROM thing_duplicates
      WHERE thing_duplicates.false_positive = FALSE
      UNION
      SELECT thing_duplicates.thing_id AS duplicate_id, thing_duplicates.thing_duplicate_id As original_id, thing_duplicates.score
      FROM thing_duplicates
      WHERE thing_duplicates.false_positive = FALSE
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW IF EXISTS duplicate_candidates;
    SQL
  end
end
