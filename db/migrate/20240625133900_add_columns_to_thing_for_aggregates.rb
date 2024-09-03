# frozen_string_literal: true

class AddColumnsToThingForAggregates < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE TYPE aggregate_type AS ENUM ('default', 'aggregate', 'belongs_to_aggregate');
    SQL

    add_column :things, :aggregate_type, :aggregate_type, default: 'default', null: false
    add_index :things, :aggregate_type
    add_column :thing_histories, :aggregate_type, :aggregate_type, default: 'default', null: false
    add_index :thing_histories, :aggregate_type
  end

  def down
    execute <<-SQL.squish
      DROP TYPE aggregate_type;
    SQL

    remove_column :things, :aggregate_type
    remove_column :thing_histories, :aggregate_type
  end
end
