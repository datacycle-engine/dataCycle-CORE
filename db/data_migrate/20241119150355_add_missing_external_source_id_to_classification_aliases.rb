# frozen_string_literal: true

class AddMissingExternalSourceIdToClassificationAliases < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      SET session_replication_role = replica;

      UPDATE classification_aliases
      SET external_source_id = ca_data.external_source_id
      FROM (
          SELECT ca.id,
            c.external_source_id
          FROM primary_classification_groups pcg
            JOIN classifications c ON c.id = pcg.classification_id
            AND c.deleted_at IS NULL
            JOIN classification_aliases ca ON ca.id = pcg.classification_alias_id
            AND ca.deleted_at IS NULL
          WHERE c.external_source_id IS NOT NULL
            AND ca.external_source_id IS NULL
        ) ca_data
      WHERE classification_aliases.id = ca_data.id;

      SET session_replication_role = DEFAULT;
    SQL
  end

  def down
  end
end
