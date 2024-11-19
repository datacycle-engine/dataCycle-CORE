# frozen_string_literal: true

class AddSomeConditionsForDoUpdate < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH direct_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_aliases.id
            ) classification_contents.content_data_id "thing_id",
            classification_aliases.id "classification_alias_id",
            classification_trees.classification_tree_label_id,
            TRUE "direct"
          FROM classification_contents
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
            JOIN classification_aliases ON classification_aliases.id = classification_groups.classification_alias_id
            JOIN classification_trees ON classification_trees.classification_alias_id = classification_aliases.id
            AND classification_trees.deleted_at IS NULL
          WHERE classification_contents.content_data_id = ANY(thing_ids)
        ),
        full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_trees.classification_alias_id
            ) classification_contents.content_data_id "thing_id",
            classification_trees.classification_alias_id "classification_alias_id",
            classification_trees.classification_tree_label_id,
            FALSE "direct"
          FROM classification_contents
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
            JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id
            JOIN classification_trees ON classification_trees.classification_alias_id = ANY (
              classification_alias_paths_transitive.full_path_ids
            )
            AND classification_trees.deleted_at IS NULL
          WHERE classification_contents.content_data_id = ANY(thing_ids)
            AND NOT EXISTS (
              SELECT 1
              FROM direct_classification_content_relations dccr
              WHERE dccr.thing_id = classification_contents.content_data_id
                AND dccr.classification_alias_id = classification_trees.classification_alias_id
            )
        ),
        new_collected_classification_contents AS (
          SELECT direct_classification_content_relations.thing_id,
            direct_classification_content_relations.classification_alias_id,
            direct_classification_content_relations.classification_tree_label_id,
            direct_classification_content_relations.direct
          FROM direct_classification_content_relations
          UNION
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            full_classification_content_relations.direct
          FROM full_classification_content_relations
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.id IN (
              SELECT ccc.id
              FROM collected_classification_contents ccc
              WHERE ccc.thing_id = ANY(thing_ids)
                AND NOT EXISTS (
                  SELECT 1
                  FROM new_collected_classification_contents
                  WHERE new_collected_classification_contents.thing_id = ccc.thing_id
                    AND new_collected_classification_contents.classification_alias_id = ccc.classification_alias_id
                )
              ORDER BY ccc.id ASC FOR
              UPDATE SKIP LOCKED
            )
        )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          direct
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.direct
      FROM new_collected_classification_contents ON CONFLICT (thing_id, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        direct = EXCLUDED.direct
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.direct IS DISTINCT
      FROM EXCLUDED.direct;

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.upsert_ca_paths(concept_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths(
          id,
          parent_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          tree_label_id
        ) AS (
          SELECT c.id,
            cl.parent_id,
            ARRAY []::uuid [],
            ARRAY [c.id],
            ARRAY [c.internal_name],
            c.concept_scheme_id
          FROM concepts c
            JOIN concept_links cl ON cl.child_id = c.id
            AND cl.link_type = 'broader'
          WHERE c.id = ANY(concept_ids)
          UNION ALL
          SELECT paths.id,
            cl.parent_id,
            ancestor_ids || c.id,
            full_path_ids || c.id,
            full_path_names || c.internal_name,
            c.concept_scheme_id
          FROM concepts c
            JOIN paths ON paths.parent_id = c.id
            JOIN concept_links cl ON cl.child_id = c.id
            AND cl.link_type = 'broader'
          WHERE c.id <> ALL (paths.full_path_ids)
        ),
        child_paths(
          id,
          ancestor_ids,
          full_path_ids,
          full_path_names
        ) AS (
          SELECT paths.id AS id,
            paths.ancestor_ids AS ancestor_ids,
            paths.full_path_ids AS full_path_ids,
            paths.full_path_names || cs.name AS full_path_names
          FROM paths
            JOIN concept_schemes cs ON cs.id = paths.tree_label_id
          WHERE paths.parent_id IS NULL
          UNION ALL
          SELECT c.id AS id,
            (cl.parent_id || p1.ancestor_ids) AS ancestors_ids,
            (c.id || p1.full_path_ids) AS full_path_ids,
            (c.internal_name || p1.full_path_names) AS full_path_names
          FROM concepts c
            JOIN concept_links cl ON cl.child_id = c.id
            AND cl.link_type = 'broader'
            JOIN child_paths p1 ON p1.id = cl.parent_id
          WHERE c.id <> ALL (p1.full_path_ids)
        )
      INSERT INTO classification_alias_paths (
          id,
          ancestor_ids,
          full_path_ids,
          full_path_names
        )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_pkey DO
      UPDATE
      SET ancestor_ids = EXCLUDED.ancestor_ids,
        full_path_ids = EXCLUDED.full_path_ids,
        full_path_names = EXCLUDED.full_path_names
      WHERE classification_alias_paths.ancestor_ids IS DISTINCT
      FROM EXCLUDED.ancestor_ids
        OR classification_alias_paths.full_path_ids IS DISTINCT
      FROM EXCLUDED.full_path_ids
        OR classification_alias_paths.full_path_names IS DISTINCT
      FROM EXCLUDED.full_path_names;

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION public.upsert_ca_paths_transitive(concept_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths(
          id,
          parent_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types,
          tree_label_id
        ) AS (
          SELECT c.id,
            cl.parent_id,
            ARRAY []::uuid [],
            ARRAY [c.id],
            ARRAY [c.internal_name],
            ARRAY [cl.link_type]::varchar [],
            c.concept_scheme_id
          FROM concepts c
            JOIN concept_links cl ON cl.child_id = c.id
          WHERE c.id = ANY(concept_ids)
          UNION ALL
          SELECT paths.id,
            cl.parent_id,
            ancestor_ids || c.id,
            full_path_ids || c.id,
            full_path_names || c.internal_name,
            CASE
              WHEN cl.parent_id IS NULL THEN paths.link_types
              ELSE paths.link_types || cl.link_type
            END,
            c.concept_scheme_id
          FROM concepts c
            JOIN paths ON paths.parent_id = c.id
            JOIN concept_links cl ON cl.child_id = c.id
          WHERE c.id <> ALL (paths.full_path_ids)
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
            paths.full_path_names || cs.name AS full_path_names,
            paths.link_types AS link_types
          FROM paths
            JOIN concept_schemes cs ON cs.id = paths.tree_label_id
          WHERE paths.parent_id IS NULL
          UNION ALL
          SELECT c.id AS id,
            (cl.parent_id || p1.ancestor_ids) AS ancestors_ids,
            (c.id || p1.full_path_ids) AS full_path_ids,
            (c.internal_name || p1.full_path_names) AS full_path_names,
            (cl.link_type || p1.link_types) AS link_types
          FROM concepts c
            JOIN concept_links cl ON cl.child_id = c.id
            JOIN child_paths p1 ON p1.id = cl.parent_id
          WHERE c.id <> ALL (p1.full_path_ids)
        ),
        deleted_capt AS (
          DELETE FROM classification_alias_paths_transitive
          WHERE classification_alias_paths_transitive.id IN (
              SELECT capt.id
              FROM classification_alias_paths_transitive capt
              WHERE capt.full_path_ids && concept_ids
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
        array_remove(child_paths.link_types, NULL)
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names
      WHERE classification_alias_paths_transitive.full_path_names IS DISTINCT
      FROM EXCLUDED.full_path_names;

      END IF;

      END;

      $$;
    SQL
  end

  def down
  end
end
