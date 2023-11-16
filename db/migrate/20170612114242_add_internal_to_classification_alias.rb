# frozen_string_literal: true

class AddInternalToClassificationAlias < ActiveRecord::Migration[5.0]
  def change
    add_column :classification_aliases, :internal, :boolean, default: false, null: false
  end
end
