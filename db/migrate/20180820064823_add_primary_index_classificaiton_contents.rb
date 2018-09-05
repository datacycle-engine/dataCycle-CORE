# frozen_string_literal: true

class AddPrimaryIndexClassificaitonContents < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      DELETE FROM classification_contents a
      USING classification_contents b
      WHERE a.id > b.id
      AND a.content_data_id = b.content_data_id
      AND a.content_data_type = b.content_data_type
      AND a.classification_id = b.classification_id
      AND a.relation = b.relation
    SQL

    execute <<-SQL
      DELETE FROM classification_content_histories a
      USING classification_content_histories b
      WHERE a.id > b.id
      AND a.content_data_history_id = b.content_data_history_id
      AND a.content_data_history_type = b.content_data_history_type
      AND a.classification_id = b.classification_id
      AND a.relation = b.relation
    SQL

    add_index :classification_contents, [:content_data_id, :content_data_type, :classification_id, :relation], unique: true, name: 'by_content_data_classification_relation'
    add_index :classification_content_histories, [:content_data_history_id, :content_data_history_type, :classification_id, :relation], unique: true, name: 'by_content_data_history_classification_relation'
  end

  def down
    remove_index :classification_contents, name: 'by_content_data_classification_relation'
    remove_index :classification_content_histories, name: 'by_content_data_history_classification_relation'
  end
end
