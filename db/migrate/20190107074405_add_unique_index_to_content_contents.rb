# frozen_string_literal: true

class AddUniqueIndexToContentContents < ActiveRecord::Migration[5.1]
  def up
    add_index :content_contents, [:content_a_id, :relation_a, :content_b_id], unique: true, name: 'by_content_relation_a'
  end

  def down
    remove_index :content_contents, name: 'by_content_relation_a'
  end
end
