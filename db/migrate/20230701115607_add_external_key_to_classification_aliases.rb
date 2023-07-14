# frozen_string_literal: true

class AddExternalKeyToClassificationAliases < ActiveRecord::Migration[6.1]
  def up
    add_column :classification_aliases, :external_key, :string

    add_foreign_key :classifications, :external_systems, column: :external_source_id, on_delete: :nullify, validate: false

    add_foreign_key :classification_aliases, :external_systems, column: :external_source_id, on_delete: :nullify, validate: false

    add_foreign_key :classification_groups, :external_systems, column: :external_source_id, on_delete: :nullify, validate: false
    add_foreign_key :classification_groups, :classifications, on_delete: :cascade, validate: false
    add_foreign_key :classification_groups, :classification_aliases, on_delete: :cascade, validate: false

    add_foreign_key :classification_trees, :external_systems, column: :external_source_id, on_delete: :nullify, validate: false
    add_foreign_key :classification_trees, :classification_tree_labels, on_delete: :cascade, validate: false
    add_foreign_key :classification_trees, :classification_aliases, on_delete: :cascade, validate: false
    add_foreign_key :classification_trees, :classification_aliases, column: :parent_classification_alias_id, on_delete: :cascade, validate: false

    add_foreign_key :classification_alias_paths_transitive, :classification_aliases, on_delete: :cascade, validate: false

    execute <<-SQL.squish
      CREATE UNIQUE INDEX index_classification_aliases_unique_external_source_id_and_key
        ON classification_aliases(external_source_id, external_key) WHERE deleted_at IS NULL;

      CREATE UNIQUE INDEX index_classifications_unique_external_source_id_and_key
        ON classifications(external_source_id, external_key) WHERE deleted_at IS NULL;

      CREATE UNIQUE INDEX index_classification_trees_unique_classification_alias
        ON classification_trees(classification_alias_id) WHERE deleted_at IS NULL;
    SQL
  end

  def down
    remove_column :classification_aliases, :external_key, :string

    remove_foreign_key :classifications, :external_systems, column: :external_source_id

    remove_foreign_key :classification_aliases, :external_systems, column: :external_source_id

    remove_foreign_key :classification_groups, :external_systems, column: :external_source_id
    remove_foreign_key :classification_groups, :classifications
    remove_foreign_key :classification_groups, :classification_aliases

    remove_foreign_key :classification_trees, :external_systems, column: :external_source_id
    remove_foreign_key :classification_trees, :classification_tree_labels
    remove_foreign_key :classification_trees, :classification_aliases
    remove_foreign_key :classification_trees, :classification_aliases, column: :parent_classification_alias_id

    remove_foreign_key :classification_alias_paths_transitive, :classification_aliases

    execute <<-SQL.squish
      DROP INDEX IF EXISTS index_classifications_unique_external_source_id_and_key;
      DROP INDEX IF EXISTS index_classification_aliases_unique_external_source_id_and_key;
      DROP INDEX IF EXISTS index_classification_trees_unique_classification_alias;
    SQL
  end
end
