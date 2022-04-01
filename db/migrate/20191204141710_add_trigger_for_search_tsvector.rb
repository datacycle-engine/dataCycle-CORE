# frozen_string_literal: true

class AddTriggerForSearchTsvector < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      CREATE TRIGGER tsvectorsearchupdate BEFORE INSERT OR UPDATE
      ON searches FOR EACH ROW EXECUTE PROCEDURE
      tsvector_update_trigger(words, 'pg_catalog.simple', full_text);
    SQL
  end

  def down
    execute <<-SQL
      DROP TRIGGER IF EXISTS tsvectorsearchupdate
      ON searches;
    SQL
  end
end
