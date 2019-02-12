# frozen_string_literal: true

class AddUniqueIndexToContentContents < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL
      DELETE FROM content_contents a
      USING content_contents b
      WHERE a.id > b.id
      AND a.content_a_id = b.content_a_id
      AND a.relation_a = b.relation_a
      AND a.content_b_id = b.content_b_id
    SQL

    add_index :content_contents, [:content_a_id, :relation_a, :content_b_id], unique: true, name: 'by_content_relation_a'
  end

  def down
    remove_index :content_contents, name: 'by_content_relation_a'
  end
end
