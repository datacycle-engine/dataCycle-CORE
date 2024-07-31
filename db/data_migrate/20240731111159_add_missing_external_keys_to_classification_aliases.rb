# frozen_string_literal: true

class AddMissingExternalKeysToClassificationAliases < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      WITH to_delete AS (
        SELECT ca2.id
        FROM primary_classification_groups pcg
          JOIN classifications c ON c.id = pcg.classification_id
          AND c.deleted_at IS NULL
          JOIN classification_aliases ca ON ca.id = pcg.classification_alias_id
          AND ca.deleted_at IS NULL
          LEFT OUTER JOIN classification_aliases ca2 ON ca2.external_source_id = c.external_source_id
          AND ca2.external_key = c.external_key
          AND ca2.deleted_at IS NULL
        WHERE c.external_key IS NOT NULL
          AND ca.id != ca2.id
      ),
      deleted_cas AS (
        UPDATE classification_aliases
        SET deleted_at = NOW()
        WHERE classification_aliases.id IN (
            SELECT to_delete.id
            FROM to_delete
          )
      ),
      deleted_groups AS (
        UPDATE classification_groups
        SET deleted_at = NOW()
        WHERE classification_groups.classification_alias_id IN (
            SELECT to_delete.id
            FROM to_delete
          )
        RETURNING *
      )
      SELECT *
      FROM deleted_groups;

      UPDATE classification_aliases
      SET external_key = ca_data.external_key
      FROM (
          SELECT ca.id,
            c.external_key
          FROM primary_classification_groups pcg
            JOIN classifications c ON c.id = pcg.classification_id
            AND c.deleted_at IS NULL
            JOIN classification_aliases ca ON ca.id = pcg.classification_alias_id
            AND ca.deleted_at IS NULL
          WHERE c.external_key IS NOT NULL
            AND ca.external_key IS NULL
        ) ca_data
      WHERE classification_aliases.id = ca_data.id;
    SQL
  end

  def down
  end
end
