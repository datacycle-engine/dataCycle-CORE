# frozen_string_literal: true

class CreateViewForClassificationAliasePaths < ActiveRecord::Migration[5.0]
  def up
    execute <<-SQL
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

  def down
    execute <<-SQL
      DROP VIEW classification_alias_paths;
    SQL
  end
end
