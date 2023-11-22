# frozen_string_literal: true

class RenameEditLinksToDataLinks < ActiveRecord::Migration[5.0]
  def up
    remove_column :edit_links, :read_only
    add_column :edit_links, :permissions, :string
    rename_table :edit_links, :data_links
  end

  def down
    remove_column :data_links, :permissions
    add_column :data_links, :read_only, :boolean, default: false, null: false
    rename_table :data_links, :edit_links
  end
end
