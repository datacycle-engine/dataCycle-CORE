# frozen_string_literal: true

class AddIndexForClassificationTreeLabelName < ActiveRecord::Migration[5.2]
  def up
    add_index :classification_tree_labels, :name unless index_exists? :classification_tree_labels, :name
    add_index :classification_trees, :classification_tree_label_id unless index_exists? :classification_trees, :classification_tree_label_id
    add_index :things, :is_part_of unless index_exists? :things, :is_part_of
    add_index :classification_groups, [:classification_id, :created_at] unless index_exists? :classification_groups, [:classification_id, :created_at]
  end

  def down
    remove_index :classification_tree_labels, :name if index_exists? :classification_tree_labels, :name
    remove_index :classification_trees, :classification_tree_label_id if index_exists? :classification_trees, :classification_tree_label_id
    remove_index :things, :is_part_of if index_exists? :things, :is_part_of
    remove_index :classification_groups, [:classification_id, :created_at] if index_exists? :classification_groups, [:classification_id, :created_at]
  end
end
