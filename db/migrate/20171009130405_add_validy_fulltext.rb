# frozen_string_literal: true

class AddValidyFulltext < ActiveRecord::Migration[5.0]
  def up
    add_column :searches, :validity_period, :tstzrange
    connection = ActiveRecord::Base.connection
    sql_query = 'CREATE INDEX validity_period_idx ON searches USING GIST (validity_period);'
    connection.exec_query(sql_query)
    add_column :searches, :all_text, :text
    sql_query = 'CREATE INDEX all_text_idx ON searches USING GIN (all_text gin_trgm_ops);'
    connection.exec_query(sql_query)
  end

  def down
    remove_index :searches, :all_text_idx
    remove_column :searches, :all_text
    remove_index :searches, :validity_period_idx
    remove_column :searches, :validity_period
  end
end
