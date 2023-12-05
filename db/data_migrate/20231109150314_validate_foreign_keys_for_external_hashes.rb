# frozen_string_literal: true

class ValidateForeignKeysForExternalHashes < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      DELETE FROM external_hashes
      WHERE external_hashes.id IN (
          SELECT eh.id
          FROM external_hashes eh
          WHERE NOT EXISTS (
              SELECT 1
              FROM thing_translations
                INNER JOIN things ON things.id = thing_translations.thing_id
              WHERE things.external_source_id = eh.external_source_id
                AND things.external_key = eh.external_key
                AND thing_translations.locale = eh.locale
            ) FOR
          UPDATE
        );

      ALTER TABLE external_hashes VALIDATE CONSTRAINT fk_external_hashes_things;
    SQL
  end

  def down
  end
end
