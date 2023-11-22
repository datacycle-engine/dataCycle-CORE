# frozen_string_literal: true

class AddForeignKeyConstraintsForExternalHashes < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE external_hashes
      ADD CONSTRAINT fk_external_hashes_things FOREIGN KEY (external_source_id, external_key) REFERENCES things (external_source_id, external_key) ON DELETE CASCADE NOT VALID;

      CREATE OR REPLACE FUNCTION delete_external_hashes_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM external_hashes
      WHERE external_hashes.id IN (
          SELECT eh.id
          FROM external_hashes eh
          WHERE EXISTS (
              SELECT 1
              FROM old_thing_translations
                INNER JOIN things ON things.id = old_thing_translations.thing_id
              WHERE things.external_source_id = eh.external_source_id
                AND things.external_key = eh.external_key
                AND old_thing_translations.locale = eh.locale
            ) FOR
          UPDATE
        );

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER delete_external_hashes_trigger
      AFTER DELETE ON thing_translations REFERENCING OLD TABLE AS old_thing_translations FOR EACH STATEMENT EXECUTE FUNCTION delete_external_hashes_trigger_1();
    SQL
  end

  def down
    execute <<-SQL.squish
      ALTER TABLE external_hashes DROP CONSTRAINT fk_external_hashes_things;

      DROP TRIGGER IF EXISTS delete_external_hashes_trigger ON thing_translations;

      DROP FUNCTION IF EXISTS delete_external_hashes_trigger_1;
    SQL
  end
end
