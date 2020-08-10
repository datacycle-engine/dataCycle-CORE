# frozen_string_literal: true

class AddIndizesToThingsForNewContentDialog < ActiveRecord::Migration[5.2]
  def up
    add_index :things, [:created_by, :created_at], name: 'by_created_by_created_at' unless index_name_exists?(:things, 'by_created_by_created_at')
    add_index :things, [:template_name, :template], name: 'by_template_name_template' unless index_name_exists?(:things, 'by_template_name_template')
  end

  def down
    remove_index :things, name: 'by_created_by_created_at' if index_name_exists?(:things, 'by_created_by_created_at')
    remove_index :things, name: 'by_template_name_template' if index_name_exists?(:things, 'by_template_name_template')
  end
end
