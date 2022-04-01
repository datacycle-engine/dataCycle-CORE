# frozen_string_literal: true

class AddWordsTypeaheadForSearch < ActiveRecord::Migration[5.2]
  def up
    add_column :searches, :words_typeahead, :tsvector
    execute <<-SQL
      CREATE TRIGGER tsvectortypeaheadsearchupdate BEFORE INSERT OR UPDATE
      ON searches FOR EACH ROW EXECUTE PROCEDURE
      tsvector_update_trigger(words_typeahead, 'pg_catalog.simple', full_text);
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS tsvectortypeaheadsearchupdate
      ON searches;
    SQL
    remove_column :searches, :words_typeahead
  end
end
