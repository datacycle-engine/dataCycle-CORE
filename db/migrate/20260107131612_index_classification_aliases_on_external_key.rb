# frozen_string_literal: true

class IndexClassificationAliasesOnExternalKey < ActiveRecord::Migration[8.0]
  def up
    execute('SET LOCAL statement_timeout = 0;')
    remove_index :classification_aliases, name: 'deleted_at_id_idx', if_exists: true
    remove_index :classification_aliases, name: 'index_classification_aliases_on_deleted_at', if_exists: true
    add_index :classification_aliases, [:deleted_at, :id]
    add_index :classification_aliases, :external_key
  end

  def down
  end
end
