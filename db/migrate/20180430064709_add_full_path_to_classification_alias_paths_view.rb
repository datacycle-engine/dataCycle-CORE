# frozen_string_literal: true

class AddFullPathToClassificationAliasPathsView < ActiveRecord::Migration[5.0]
  def up
    execute <<-SQL
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
  end

  def down
    execute <<-SQL
      DROP VIEW classification_alias_paths;

      CREATE RECURSIVE VIEW classification_alias_paths(id, ancestor_names, ancestor_ids) AS (
        SELECT
      		classification_aliases.id,
      		ARRAY[classification_tree_labels.name, classification_aliases.name] as ancestor_names,
      		ARRAY[]::uuid[] as ancestor_ids
      	FROM classification_trees
      	JOIN classification_aliases ON classification_aliases.id = classification_alias_id
      	JOIN classification_tree_labels ON classification_tree_labels.id = classification_tree_label_id
      	WHERE parent_classification_alias_id IS NULL
      UNION ALL
      	SELECT
      		classification_aliases.id,
      		ancestor_names || classification_aliases.name as ancestor_names,
      		ancestor_ids || classification_alias_paths.id as ancestor_ids
      	FROM classification_trees
      	JOIN classification_alias_paths ON classification_alias_paths.id = classification_trees.parent_classification_alias_id
      	JOIN classification_aliases ON classification_aliases.id = classification_alias_id
      );
    SQL
  end
end
