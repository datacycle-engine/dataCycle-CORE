# frozen_string_literal: true

class AddTableForDataMigrations < ActiveRecord::Migration[8.0]
  def up
    create_table :data_migrations, id: false do |t|
      t.string :version, null: false, primary_key: true
    end

    execute <<~SQL.squish
      INSERT INTO data_migrations (version)
      SELECT version FROM schema_migrations
    SQL
  end

  def down
    drop_table :data_migrations
  end
end
