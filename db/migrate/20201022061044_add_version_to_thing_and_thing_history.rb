# frozen_string_literal: true

class AddVersionToThingAndThingHistory < ActiveRecord::Migration[5.2]
  def up
    add_column :things, :version_name, :string
    add_column :thing_histories, :version_name, :string

    remove_index :thing_histories, name: 'index_thing_histories_on_thing_id' if index_name_exists?(:thing_histories, 'index_thing_histories_on_thing_id')
    add_index :thing_histories, [:thing_id, :version_name], name: 'by_thing_id_version_name' unless index_name_exists?(:thing_histories, 'by_thing_id_version_name')
  end

  def down
    remove_index :thing_histories, name: 'by_thing_id_version_name' if index_name_exists?(:thing_histories, 'by_thing_id_version_name')
    add_index :thing_histories, :thing_id, name: 'index_thing_histories_on_thing_id' unless index_name_exists?(:thing_histories, 'index_thing_histories_on_thing_id')

    remove_column :things, :version_name
    remove_column :thing_histories, :version_name
  end
end
