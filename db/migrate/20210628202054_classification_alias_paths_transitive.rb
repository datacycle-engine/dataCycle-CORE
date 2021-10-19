# frozen_string_literal: true

class ClassificationAliasPathsTransitive < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      CREATE OR REPLACE VIEW classification_alias_links AS (
      	WITH primary_classification_groups AS (
      		SELECT DISTINCT
      			classification_alias_id,
      			FIRST_VALUE(classification_id) OVER (
              PARTITION BY classification_alias_id ORDER BY created_at
            ) "classification_id"
      		FROM classification_groups
      	)
        SELECT
      		primary_classification_groups.classification_alias_id "parent_classification_alias_id",
      		additional_classification_groups.classification_alias_id "child_classification_alias_id",
      		'related' "link_type"
      	FROM primary_classification_groups
      	JOIN classification_groups "additional_classification_groups" ON
      		primary_classification_groups.classification_id = additional_classification_groups.classification_id AND
      		additional_classification_groups.classification_alias_id != primary_classification_groups.classification_alias_id
      	UNION
      	SELECT
          parent_classification_alias_id,
          classification_trees.classification_alias_id "child_classification_alias_id",
          'broader' "link_type"
      	FROM classification_trees
      );

      CREATE OR REPLACE RECURSIVE VIEW classification_alias_paths_transitive(
        id,
        ancestors_ids,
        full_path_ids,
        full_path_names,link_types
      ) AS (
      	SELECT
      		child_classification_alias_id "id",
      		ARRAY[]::uuid[] "ancestors_ids",
      		ARRAY[child_classification_alias_id] "full_path_ids",
      		ARRAY[internal_name, classification_tree_labels.name] "full_path_names",
      		ARRAY[]::text[] "link_types"
      	FROM classification_alias_links
      	JOIN classification_aliases ON
          classification_aliases.id = classification_alias_links.child_classification_alias_id
      	JOIN classification_trees ON
          classification_trees.parent_classification_alias_id IS NULL AND
          classification_trees.classification_alias_id = classification_aliases.id
      	JOIN classification_tree_labels ON
          classification_tree_labels.id = classification_tree_label_id
      	WHERE classification_alias_links.parent_classification_alias_id IS NULL
       	UNION ALL
       	SElECT
      		child_classification_alias_id "id",
      		classification_alias_links.parent_classification_alias_id || ancestors_ids "ancestors_ids",
          classification_aliases.id || full_path_ids "full_path_ids",
          classification_aliases.internal_name || full_path_names "full_path_names",
          classification_alias_links.link_type || link_types "link_types"
      	FROM classification_alias_links
      	JOIN classification_aliases ON
          classification_aliases.id = classification_alias_links.child_classification_alias_id
      	JOIN classification_alias_paths_transitive ON
          classification_alias_paths_transitive.id = classification_alias_links.parent_classification_alias_id
      	WHERE child_classification_alias_id != ALL(full_path_ids)
      );
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP VIEW classification_alias_paths_transitive;
      DROP VIEW classification_alias_links;
    SQL
  end
end
