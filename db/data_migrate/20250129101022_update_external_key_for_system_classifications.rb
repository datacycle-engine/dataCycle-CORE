# frozen_string_literal: true

# Not ported to concepts by #41458, unlike RenameLocalBusinessContentTypeToBetrieb, because the
# backfill has nothing left to do: all 65 project checkouts pin a core that already contains this
# file, so it has run everywhere, and ConceptImporter already assigns the very keys the UPDATEs
# below compute while parsing a classifications.yml - a scheme's name, a concept's ' > '-joined
# path. The system rows still carrying none are the ones the backend creates, whose create_params
# permit no external_key; giving those a key is a question about the UI, not a migration.
class UpdateExternalKeyForSystemClassifications < ActiveRecord::Migration[7.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    return say('the pre-concept classification tables are gone (see #41458); nothing to migrate') unless table_exists?(:classification_aliases)

    execute <<~SQL.squish
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
