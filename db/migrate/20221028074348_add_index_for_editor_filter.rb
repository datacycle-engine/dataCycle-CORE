# frozen_string_literal: true

class AddIndexForEditorFilter < ActiveRecord::Migration[6.1]
  def change
    add_index :things, :updated_by, name: 'index_things_on_updated_by', if_not_exists: true
    add_index :thing_histories, :updated_by, name: 'index_thing_histories_on_updated_by', if_not_exists: true
  end
end
