# frozen_string_literal: true

class AddDeletedAtToClassificationClasses < ActiveRecord::Migration[5.0]
  def change
    add_column :classifications, :deleted_at, :datetime
    add_index :classifications, :deleted_at

    add_column :classification_aliases, :deleted_at, :datetime
    add_index :classification_aliases, :deleted_at

    add_column :classification_groups, :deleted_at, :datetime
    add_index :classification_groups, :deleted_at

    add_column :classification_trees, :deleted_at, :datetime
    add_index :classification_trees, :deleted_at

    add_column :classification_tree_labels, :deleted_at, :datetime
    add_index :classification_tree_labels, :deleted_at
  end
end
