# frozen_string_literal: true

class AddClassificationsIndexesToSearch < ActiveRecord::Migration[5.0]
  def up
    add_column :searches, :classification_string, :string
    connection = ActiveRecord::Base.connection
    sql_query = 'CREATE INDEX classification_string_idx ON searches USING GIN (classification_string gin_trgm_ops);'
    connection.exec_query(sql_query)
    sql_query = 'CREATE INDEX headline_idx ON searches USING GIN (headline gin_trgm_ops);'
    connection.exec_query(sql_query)
  end

  def down
    remove_index :searches, name: 'headline_idx'
    remove_index :searches, name: 'classification_string_idx'
    remove_column :searches, :classification_string
  end
end
