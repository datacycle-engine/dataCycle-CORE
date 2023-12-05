# frozen_string_literal: true

class AddAssignableToClassificationAlias < ActiveRecord::Migration[5.0]
  def up
    add_column :classification_aliases, :assignable, :boolean, default: true, null: false
  end

  def down
    remove_column :classification_aliases, :assignable
  end
end
