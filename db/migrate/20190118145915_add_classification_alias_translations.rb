# frozen_string_literal: true

class AddClassificationAliasTranslations < ActiveRecord::Migration[5.1]
  # rubocop:disable Rails/BulkChangeTable
  def change
    add_column :classification_aliases, :name_i18n, :jsonb, default: {}
    add_column :classification_aliases, :description_i18n, :jsonb, default: {}
    rename_column :classification_aliases, :name, :internal_name
    rename_column :classification_aliases, :description, :internal_description # just to keep the old data available

    reversible do |direction|
      direction.up do
        execute <<-SQL
          UPDATE classification_aliases SET
            name_i18n = jsonb_build_object('de', internal_name),
            description_i18n = json_build_object('de', internal_description)
        SQL
      end
    end

    reversible do |direction|
      direction.up do
        execute <<-SQL
          DROP VIEW classification_alias_statistics;
          DROP VIEW classification_alias_paths;

          CREATE RECURSIVE VIEW classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names) AS (
            SELECT
          	  classification_aliases.id,
              ARRAY[]::uuid[] AS ancestor_ids,
              ARRAY[classification_aliases.id] AS full_path_ids,
          	  ARRAY[classification_aliases.internal_name, classification_tree_labels.name] AS full_path_names
          	FROM classification_trees
          	JOIN classification_aliases ON classification_aliases.id = classification_alias_id
          	JOIN classification_tree_labels ON classification_tree_labels.id = classification_tree_label_id
          	WHERE parent_classification_alias_id IS NULL
          UNION ALL
          	SELECT
          	  classification_aliases.id,
              classification_alias_paths.id || ancestor_ids AS ancestor_ids,
              classification_aliases.id || full_path_ids AS full_path_ids,
          	  classification_aliases.internal_name || full_path_names AS full_path_names
          	FROM classification_trees
          	JOIN classification_alias_paths ON classification_alias_paths.id = classification_trees.parent_classification_alias_id
          	JOIN classification_aliases ON classification_aliases.id = classification_alias_id
          );
        SQL

        recreate_classification_alias_statistics
      end
      direction.down do
        execute <<-SQL
          DROP VIEW classification_alias_statistics;
          DROP VIEW classification_alias_paths;

          CREATE RECURSIVE VIEW classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names) AS (
            SELECT
              classification_aliases.id,
              ARRAY[]::uuid[] AS ancestor_ids,
              ARRAY[classification_aliases.id] AS full_path_ids,
              ARRAY[classification_aliases.name, classification_tree_labels.name] AS full_path_names
            FROM classification_trees
            JOIN classification_aliases ON classification_aliases.id = classification_alias_id
            JOIN classification_tree_labels ON classification_tree_labels.id = classification_tree_label_id
            WHERE parent_classification_alias_id IS NULL
          UNION ALL
            SELECT
              classification_aliases.id,
              classification_alias_paths.id || ancestor_ids AS ancestor_ids,
              classification_aliases.id || full_path_ids AS full_path_ids,
              classification_aliases.name || full_path_names AS full_path_names
            FROM classification_trees
            JOIN classification_alias_paths ON classification_alias_paths.id = classification_trees.parent_classification_alias_id
            JOIN classification_aliases ON classification_aliases.id = classification_alias_id
          );
        SQL

        recreate_classification_alias_statistics
      end
    end
  end

  def recreate_classification_alias_statistics
    execute <<-SQL
      CREATE VIEW classification_alias_statistics AS (
        WITH descendant_counts AS (
          SELECT
            classification_aliases.id,
            COUNT(CASE WHEN ancestor_id IS NOT NULL THEN 1 END) descendant_count
          FROM classification_aliases
            JOIN (SELECT UNNEST(ancestor_ids) ancestor_id FROM classification_alias_paths) AS exploded_classification_ancestors ON ancestor_id = classification_aliases.id
          GROUP BY classification_aliases.id
        ), linked_content_counts AS (
          SELECT
            classification_aliases.id,
            COUNT(CASE WHEN classification_aliases.id IS NOT NULL THEN 1 END) linked_content_count
          FROM classification_aliases
            JOIN classification_alias_paths ON classification_aliases.id = classification_alias_paths.id
            JOIN classification_groups ON classification_aliases.id = classification_groups.classification_alias_id
            JOIN classification_contents ON classification_groups.classification_id = classification_contents.classification_id
          GROUP BY classification_aliases.id
        ), descendants_linked_content_counts AS (
          SELECT
            ancestor_id id,
            COUNT(*) linked_content_count
          FROM (
                SELECT UNNEST(ancestor_ids) ancestor_id, id classification_alias_id
                FROM classification_alias_paths
              ) AS exploded_classification_ancestors
            JOIN classification_groups ON exploded_classification_ancestors.classification_alias_id = classification_groups.classification_alias_id
            JOIN classification_contents ON classification_groups.classification_id = classification_contents.classification_id
          GROUP BY ancestor_id
        ) SELECT
          classification_aliases.id,
          COALESCE(descendant_count, 0) descendant_count,
          COALESCE(linked_content_counts.linked_content_count, 0) + COALESCE(descendants_linked_content_counts.linked_content_count, 0) linked_content_count
        FROM classification_aliases
          LEFT JOIN descendant_counts ON descendant_counts.id = classification_aliases.id
          LEFT JOIN linked_content_counts ON linked_content_counts.id = classification_aliases.id
          LEFT JOIN descendants_linked_content_counts ON descendants_linked_content_counts.id = classification_aliases.id
      );
    SQL
  end
  # rubocop:enable Rails/BulkChangeTable
end
