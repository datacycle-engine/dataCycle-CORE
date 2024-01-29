# frozen_string_literal: true

class FinallyFixTransitivePathFunction < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(classification_alias_ids, 1) > 0 THEN WITH RECURSIVE paths(
          id,
          parent_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types,
          tree_label_id
        ) AS (
          SELECT ca.id,
            cal.parent_classification_alias_id,
            ARRAY []::uuid [],
            ARRAY [ca.id],
            ARRAY [ca.internal_name],
            ARRAY []::text [],
            ct.classification_tree_label_id
          FROM classification_alias_links cal
            JOIN classification_aliases ca ON ca.id = cal.child_classification_alias_id
            AND ca.deleted_at IS NULL
            JOIN classification_trees ct ON ct.classification_alias_id = ca.id
            AND ct.deleted_at IS NULL
          WHERE cal.child_classification_alias_id = ANY(classification_alias_ids)
          UNION ALL
          SELECT paths.id,
            cal.parent_classification_alias_id,
            ancestor_ids || ca.id,
            full_path_ids || ca.id,
            full_path_names || ca.internal_name,
            ARRAY [cal.link_type]::text [] || paths.link_types,
            ct.classification_tree_label_id
          FROM classification_alias_links cal
            JOIN paths ON paths.parent_id = cal.child_classification_alias_id
            JOIN classification_aliases ca ON ca.id = cal.child_classification_alias_id
            AND ca.deleted_at IS NULL
            JOIN classification_trees ct ON ct.classification_alias_id = ca.id
            AND ct.deleted_at IS NULL
          WHERE ca.id <> ALL (paths.full_path_ids)
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
        ),
        deleted_capt AS (
          DELETE FROM classification_alias_paths_transitive
          WHERE classification_alias_paths_transitive.id IN (
              SELECT capt.id
              FROM classification_alias_paths_transitive capt
              WHERE capt.full_path_ids && classification_alias_ids
                AND NOT EXISTS (
                  SELECT 1
                  FROM child_paths
                  WHERE child_paths.full_path_ids = capt.full_path_ids
                )
              ORDER BY capt.id ASC FOR
              UPDATE SKIP LOCKED
            )
        )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types
        )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        child_paths.link_types
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names;

      END IF;

      END;

      $$;

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_aliases;

      DROP FUNCTION generate_ca_paths_transitive_statement_trigger_1;

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_tree_labels;

      DROP FUNCTION generate_ca_paths_transitive_statement_trigger_2;

      DROP TRIGGER IF EXISTS generate_classification_alias_paths_trigger ON classification_aliases;

      DROP TRIGGER IF EXISTS generate_classification_alias_paths_trigger ON classification_tree_labels;
    SQL
  end

  def down
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(classification_alias_ids, 1) > 0 THEN WITH RECURSIVE paths(
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
      ),
      deleted_capt AS (
        DELETE FROM classification_alias_paths_transitive
        WHERE classification_alias_paths_transitive.id IN (
            SELECT capt.id
            FROM classification_alias_paths_transitive capt
            WHERE capt.full_path_ids && classification_alias_ids
              AND NOT EXISTS (
                SELECT 1
                FROM child_paths
                WHERE child_paths.full_path_ids = capt.full_path_ids
              )
            ORDER BY capt.id ASC FOR
            UPDATE SKIP LOCKED
          )
      )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types
        )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        child_paths.link_types
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names;

      END IF;

      END;

      $$;
    SQL
  end
end
