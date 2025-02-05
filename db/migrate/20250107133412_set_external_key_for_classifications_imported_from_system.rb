# frozen_string_literal: true

class SetExternalKeyForClassificationsImportedFromSystem < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      SET LOCAL statement_timeout = 0;

      UPDATE classification_tree_labels
      SET external_key = ctl.external_key
      FROM (
          SELECT ctl.id,
            ctl.name AS "external_key"
          FROM classification_tree_labels ctl
          WHERE ctl.external_source_id IS NULL
            AND ctl.external_key IS NULL
        ) ctl
      WHERE classification_tree_labels.id = ctl.id;

      UPDATE classification_aliases
      SET external_key = ca.external_key
      FROM (
          SELECT ca.id,
            ARRAY_TO_STRING(ARRAY_REVERSE(cap.full_path_names), ' > ') AS "external_key"
          FROM classification_aliases ca
            JOIN classification_alias_paths cap ON cap.id = ca.id
          WHERE ca.external_source_id IS NULL
            AND ca.external_key IS NULL
        ) ca
      WHERE classification_aliases.id = ca.id;

      UPDATE classifications
      SET external_key = c.external_key
      FROM (
          SELECT c.id,
            ARRAY_TO_STRING(ARRAY_REVERSE(cap.full_path_names), ' > ') AS "external_key"
          FROM classifications c
            JOIN concepts ON concepts.classification_id = c.id
            JOIN classification_alias_paths cap ON cap.id = concepts.id
          WHERE c.external_source_id IS NULL
            AND c.external_key IS NULL
        ) c
      WHERE classifications.id = c.id;
    SQL
  end

  def down
  end
end
