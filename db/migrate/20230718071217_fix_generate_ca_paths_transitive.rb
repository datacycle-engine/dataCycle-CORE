# frozen_string_literal: true

class FixGenerateCaPathsTransitive < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM classification_alias_paths_transitive
      WHERE full_path_ids && classification_alias_ids;

      WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types,
        tree_label_id
      ) AS (
        SELECT classification_aliases.id,
          classification_trees.parent_classification_alias_id,
          ARRAY []::uuid [],
          ARRAY [classification_aliases.id],
          ARRAY [classification_aliases.internal_name],
          ARRAY []::text [],
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
        WHERE classification_trees.classification_alias_id = ANY(classification_alias_ids)
        UNION ALL
        SELECT paths.id,
          classification_trees.parent_classification_alias_id,
          ancestor_ids || classification_aliases.id,
          full_path_ids || classification_aliases.id,
          full_path_names || classification_aliases.internal_name,
          ARRAY ['broader'] || paths.link_types,
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN paths ON paths.parent_id = classification_trees.classification_alias_id
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
      ),
      child_paths(
        id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types
      ) AS (
        SELECT paths.id AS id,
          paths.ancestor_ids AS ancestor_ids,
          paths.full_path_ids AS full_path_ids,
          paths.full_path_names || classification_tree_labels.name AS full_path_names,
          paths.link_types AS link_types
        FROM paths
          JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT classification_aliases.id AS id,
          (
            classification_alias_links.parent_classification_alias_id || p1.ancestor_ids
          ) AS ancestors_ids,
          (
            classification_aliases.id || p1.full_path_ids
          ) AS full_path_ids,
          (
            classification_aliases.internal_name || p1.full_path_names
          ) AS full_path_names,
          (
            classification_alias_links.link_type || p1.link_types
          ) AS link_types
        FROM classification_alias_links
          JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
          JOIN child_paths p1 ON p1.id = classification_alias_links.parent_classification_alias_id
        WHERE classification_aliases.id <> ALL (p1.full_path_ids)
      )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types
        )
      SELECT DISTINCT child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        child_paths.link_types
      FROM child_paths;

      RETURN;

      END;

      $$;
    SQL
  end

  def down
  end
end
