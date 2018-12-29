# frozen_string_literal: true

class CreateViewForPrimaryClassificationAliases < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL.squish
      CREATE VIEW primary_classification_groups AS
      SELECT DISTINCT ON (classification_id) *
      FROM classification_groups
      ORDER BY classification_id, classification_groups.created_at ASC;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW primary_classification_groups;
    SQL
  end
end
