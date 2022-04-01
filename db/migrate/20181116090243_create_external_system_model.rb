# frozen_string_literal: true

class CreateExternalSystemModel < ActiveRecord::Migration[5.1]
  def up
    create_table :external_systems, id: :uuid do |t|
      t.string :name
      t.jsonb :config
      t.jsonb :credentials
      t.jsonb :default_options
      t.jsonb :data
      t.timestamps
    end

    create_table :thing_external_systems, id: :uuid do |t|
      t.uuid :thing_id
      t.uuid :external_system_id
      t.jsonb :data
      t.timestamps
    end

    add_index :external_systems, :id, unique: true
    add_index :thing_external_systems, [:thing_id, :external_system_id], unique: true
  end

  def down
    drop_table :external_systems
    drop_table :thing_external_systems
  end
end
