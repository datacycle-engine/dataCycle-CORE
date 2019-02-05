# frozen_string_literal: true

class AddUniqueIndexToClassificationContents < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS index_classification_contents_on_unique_constraint ON classification_contents (content_data_id, classification_id, relation)
    SQL
  end

  def down
    execute <<-SQL
      DROP INDEX IF EXISTS index_classification_contents_on_unique_constraint;
    SQL
  end
end
