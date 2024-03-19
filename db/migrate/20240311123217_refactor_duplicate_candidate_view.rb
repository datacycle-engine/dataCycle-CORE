# frozen_string_literal: true

class RefactorDuplicateCandidateView < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP VIEW duplicate_candidates;

      CREATE VIEW duplicate_candidates AS
      SELECT thing_duplicates.thing_duplicate_id AS duplicate_id,
        thing_duplicates.thing_id AS original_id,
        thing_duplicates.score,
        thing_duplicates.method AS duplicate_method,
        thing_duplicates.id AS thing_duplicate_id,
        thing_duplicates.false_positive
      FROM thing_duplicates
      UNION ALL
      SELECT thing_duplicates.thing_id AS duplicate_id,
        thing_duplicates.thing_duplicate_id AS original_id,
        thing_duplicates.score,
        thing_duplicates.method AS duplicate_method,
        thing_duplicates.id AS thing_duplicate_id,
        thing_duplicates.false_positive
      FROM thing_duplicates;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW duplicate_candidates;

      CREATE VIEW duplicate_candidates AS
      SELECT thing_duplicates.thing_duplicate_id AS duplicate_id,
        thing_duplicates.thing_id AS original_id,
        thing_duplicates.score,
        thing_duplicates.method AS duplicate_method,
        thing_duplicates.id AS thing_duplicate_id,
        thing_duplicates.false_positive
      FROM thing_duplicates
      UNION
      SELECT thing_duplicates.thing_id AS duplicate_id,
        thing_duplicates.thing_duplicate_id AS original_id,
        thing_duplicates.score,
        thing_duplicates.method AS duplicate_method,
        thing_duplicates.id AS thing_duplicate_id,
        thing_duplicates.false_positive
      FROM thing_duplicates;
    SQL
  end
end
