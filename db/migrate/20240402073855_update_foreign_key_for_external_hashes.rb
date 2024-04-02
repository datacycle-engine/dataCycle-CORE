# frozen_string_literal: true

class UpdateForeignKeyForExternalHashes < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE external_hashes DROP CONSTRAINT fk_external_hashes_things;

      ALTER TABLE external_hashes
      ADD CONSTRAINT fk_external_hashes_things FOREIGN KEY (external_source_id, external_key) REFERENCES things (external_source_id, external_key) ON DELETE CASCADE;
    SQL

    execute <<-SQL.squish
      CREATE FUNCTION delete_things_external_source_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM external_hashes eh
      WHERE eh.external_source_id = OLD.external_source_id
        AND eh.external_key = OLD.external_key;

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER delete_things_external_source_trigger BEFORE
      UPDATE OF external_key,
        external_source_id ON things FOR EACH ROW
        WHEN (
          OLD.external_key IS DISTINCT
          FROM NEW.external_key
            OR OLD.external_source_id IS DISTINCT
          FROM NEW.external_source_id
            AND NEW.external_key IS NULL
            AND NEW.external_source_id IS NULL
        ) EXECUTE FUNCTION delete_things_external_source_trigger_function();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS delete_things_external_source_trigger ON things;
      DROP FUNCTION IF EXISTS delete_things_external_source_trigger_function;

      ALTER TABLE external_hashes DROP CONSTRAINT fk_external_hashes_things;

      ALTER TABLE external_hashes
      ADD CONSTRAINT fk_external_hashes_things FOREIGN KEY (external_source_id, external_key) REFERENCES things (external_source_id, external_key) ON DELETE CASCADE ON UPDATE CASCADE NOT VALID;
    SQL
  end
end
