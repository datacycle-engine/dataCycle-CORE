class AddAssignableToClassificationAlias < ActiveRecord::Migration[5.0]
  def up
    add_column :classification_aliases, :assignable, :boolean, default: true
  end

  def down
    remove_column :classification_aliases, :assignable
  end
end
