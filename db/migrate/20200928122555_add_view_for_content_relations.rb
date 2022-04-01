# frozen_string_literal: true

class AddViewForContentRelations < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL.squish
      CREATE VIEW content_content_relations AS
      SELECT e.content_b_id AS src, e.content_a_id AS dest
      FROM content_contents e
      UNION ALL
      SELECT f.content_a_id AS src, f.content_b_id AS dest
      FROM content_contents f
      WHERE (f.relation_b IS NOT NULL);
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW IF EXISTS content_content_relations;
    SQL
  end
end
