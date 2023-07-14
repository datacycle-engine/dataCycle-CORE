# frozen_string_literal: true

class ValidateForeignKeysForClassifications < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE classifications
      SET external_source_id = NULL
      WHERE classifications.external_source_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM external_systems
        WHERE external_systems.id = classifications.external_source_id
      );

      UPDATE classification_aliases
      SET external_source_id = NULL
      WHERE classification_aliases.external_source_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM external_systems
        WHERE external_systems.id = classification_aliases.external_source_id
      );

      UPDATE classification_groups
      SET external_source_id = NULL
      WHERE classification_groups.external_source_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM external_systems
        WHERE external_systems.id = classification_groups.external_source_id
      );

      DELETE FROM classification_groups
      WHERE NOT EXISTS (
        SELECT 1
        FROM classifications
        WHERE classifications.id = classification_groups.classification_id
      );

      DELETE FROM classification_groups
      WHERE NOT EXISTS (
        SELECT 1
        FROM classification_aliases
        WHERE classification_aliases.id = classification_groups.classification_alias_id
      );

      UPDATE classification_trees
      SET external_source_id = NULL
      WHERE classification_trees.external_source_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM external_systems
        WHERE external_systems.id = classification_trees.external_source_id
      );

      DELETE FROM classification_trees
      WHERE NOT EXISTS (
        SELECT 1
        FROM classification_tree_labels
        WHERE classification_tree_labels.id = classification_trees.classification_tree_label_id
      );

      DELETE FROM classification_trees
      WHERE NOT EXISTS (
        SELECT 1
        FROM classification_aliases
        WHERE classification_aliases.id = classification_trees.classification_alias_id
      );

      DELETE FROM classification_trees
      WHERE classification_trees.parent_classification_alias_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1
        FROM classification_aliases
        WHERE classification_aliases.id = classification_trees.parent_classification_alias_id
      );

      DELETE FROM classification_alias_paths_transitive
      WHERE NOT EXISTS (
        SELECT 1
        FROM classification_aliases
        WHERE classification_aliases.id = classification_alias_paths_transitive.classification_alias_id
      );
    SQL

    validate_foreign_key :classifications, :external_systems
    validate_foreign_key :classification_aliases, :external_systems
    validate_foreign_key :classification_groups, :external_systems
    validate_foreign_key :classification_groups, :classifications
    validate_foreign_key :classification_groups, :classification_aliases
    validate_foreign_key :classification_trees, :external_systems
    validate_foreign_key :classification_trees, :classification_tree_labels
    validate_foreign_key :classification_trees, :classification_aliases
    validate_foreign_key :classification_trees, :classification_aliases
    validate_foreign_key :classification_alias_paths_transitive, :classification_aliases
  end

  def down
  end
end
