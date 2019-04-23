# frozen_string_literal: true

class CreateViewForClassificationStatistics < ActiveRecord::Migration[5.1]
  def up
    execute <<-SQL.squish
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

    execute <<-SQL.squish
      CREATE VIEW classification_tree_label_statistics AS (
        WITH descendant_counts AS (
          SELECT
            classification_tree_labels.id,
            COUNT(CASE WHEN classification_aliases.id IS NOT NULL THEN 1 END) descendant_count
          FROM classification_tree_labels
            JOIN classification_trees ON classification_tree_labels.id = classification_tree_label_id
            JOIN classification_aliases ON classification_alias_id = classification_aliases.id
          GROUP BY classification_tree_labels.id
        ), linked_content_counts AS (
          SELECT
            classification_tree_labels.id,
            COUNT(CASE WHEN classification_aliases.id IS NOT NULL THEN 1 END) linked_content_count
          FROM classification_tree_labels
            JOIN classification_trees ON classification_tree_labels.id = classification_tree_label_id
            JOIN classification_aliases ON classification_alias_id = classification_aliases.id
            JOIN classification_groups ON classification_aliases.id = classification_groups.classification_alias_id
            JOIN classification_contents ON classification_groups.classification_id = classification_contents.classification_id
          GROUP BY classification_tree_labels.id
        ) SELECT
          classification_tree_labels.id,
          COALESCE(descendant_counts.descendant_count, 0) descendant_count,
          COALESCE(linked_content_counts.linked_content_count, 0) linked_content_count
        FROM classification_tree_labels
          LEFT JOIN descendant_counts ON descendant_counts.id = classification_tree_labels.id
          LEFT JOIN linked_content_counts ON linked_content_counts.id = classification_tree_labels.id
      );
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW classification_alias_statistics;
    SQL

    execute <<-SQL.squish
      DROP VIEW classification_tree_label_statistics;
    SQL
  end
end
