# frozen_string_literal: true

class AddIndexSearch < ActiveRecord::Migration[5.0]
  def up
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')
    connection = ActiveRecord::Base.connection
    sql_query = 'CREATE INDEX words_idx ON searches USING GIN (full_text gin_trgm_ops);'
    connection.exec_query(sql_query)
    sql_query = 'CREATE INDEX name_idx ON classification_aliases USING GIN (name gin_trgm_ops);'
    connection.exec_query(sql_query)
    add_index :searches, :words, using: 'GIN'
    add_index :classification_contents, :classification_id
    add_index :classification_contents, :content_data_id
  end

  def down
    remove_index :classification_contents, :content_data_id
    remove_index :classification_contents, :classification_id
    remove_index :searches, :words
    remove_index :classification_aliases, name: 'name_idx'
    remove_index :searches, name: 'words_idx'
    disable_extension 'pg_trgm' if extension_enabled?('pg_trgm')
  end
end
