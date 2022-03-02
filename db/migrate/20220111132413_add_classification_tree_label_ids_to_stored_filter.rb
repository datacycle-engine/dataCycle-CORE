# frozen_string_literal: true

class AddClassificationTreeLabelIdsToStoredFilter < ActiveRecord::Migration[5.2]
  def up
    add_column :stored_filters, :classification_tree_labels, :uuid, array: true
  end

  def down
    remove_column :stored_filters, :classification_tree_labels
  end
end
