# frozen_string_literal: true

class AddIndexToTranslationName < ActiveRecord::Migration[5.2]
  def up
    sql_query = 'CREATE INDEX thing_translations_name_idx ON thing_translations USING GIN (name gin_trgm_ops);'
    connection.exec_query(sql_query)
  end

  def down
    remove_index :thing_translations, name: 'thing_translations_name_idx'
  end
end
