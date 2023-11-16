# frozen_string_literal: true

class AddInternalFlagToClassificationTreeLabels < ActiveRecord::Migration[5.0]
  def change
    add_column :classification_tree_labels, :internal, :boolean, default: false, null: false
  end
end
