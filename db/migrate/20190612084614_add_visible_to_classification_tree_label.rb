# frozen_string_literal: true

class AddVisibleToClassificationTreeLabel < ActiveRecord::Migration[5.1]
  def change
    add_column :classification_tree_labels, :visibility, :string, array: true, default: []
  end
end
