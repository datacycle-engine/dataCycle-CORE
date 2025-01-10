# frozen_string_literal: true

class CleanClassificationContentsForNullRelations < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      DELETE FROM classification_contents
      WHERE classification_contents.relation IS NULL;

      ALTER TABLE classification_contents
      ALTER COLUMN relation
      SET NOT NULL;
    SQL
  end

  def down
  end
end
