# frozen_string_literal: true

class FixCollectedClassificationContentTriggerFunctions < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_classification_content_relations(
          content_ids uuid [],
          excluded_classification_ids uuid []
        ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      DELETE FROM collected_classification_contents
      WHERE thing_id IN (
          SELECT cccr.thing_id
          FROM collected_classification_contents cccr
          WHERE cccr.thing_id = ANY (content_ids)
          ORDER BY cccr.thing_id ASC FOR
          UPDATE SKIP LOCKED
        );

      WITH full_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_trees.classification_alias_id
          ) classification_contents.content_data_id "thing_id",
          classification_trees.classification_alias_id "classification_alias_id",
          classification_trees.classification_tree_label_id "classification_tree_label_id",
          CASE
            WHEN classification_alias_paths.id = classification_trees.classification_alias_id THEN 'direct'
            ELSE 'broader'
          END AS "link_type"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
          JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths.full_path_ids)
          AND classification_trees.deleted_at IS NULL
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type
        )
      SELECT full_classification_content_relations.thing_id,
        full_classification_content_relations.classification_alias_id,
        full_classification_content_relations.classification_tree_label_id,
        full_classification_content_relations.link_type
      FROM full_classification_content_relations ON CONFLICT (thing_id, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type;

      RETURN;

      END;

      $$;
    SQL

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_trees.classification_alias_id
            ) classification_contents.content_data_id "thing_id",
            classification_trees.classification_alias_id "classification_alias_id",
            classification_trees.classification_tree_label_id,
            classification_groups.classification_alias_id = classification_trees.classification_alias_id "direct",
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              classification_alias_paths_transitive.id,
              classification_trees.classification_tree_label_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
            JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id
            JOIN classification_trees ON classification_trees.classification_alias_id = ANY (
              classification_alias_paths_transitive.full_path_ids
            )
            AND classification_trees.deleted_at IS NULL
            JOIN classification_alias_paths cap ON cap.id = classification_trees.classification_alias_id
          WHERE classification_contents.content_data_id = ANY(thing_ids)
          ORDER BY classification_contents.content_data_id, classification_trees.classification_alias_id, ARRAY_REVERSE(classification_alias_paths_transitive.full_path_ids) ASC
        ),
        new_collected_classification_contents AS (
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
              WHEN full_classification_content_relations.direct THEN 'direct'
              WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'related'
            END AS "link_type"
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
          link_type
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type
      FROM new_collected_classification_contents ON CONFLICT (thing_id, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type;

      END IF;

      END;

      $$;
    SQL

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_trees.classification_alias_id
            ) classification_contents.content_data_id "thing_id",
            classification_trees.classification_alias_id "classification_alias_id",
            classification_trees.classification_tree_label_id,
            classification_groups.classification_alias_id = classification_trees.classification_alias_id "direct",
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              classification_alias_paths_transitive.id,
              classification_trees.classification_tree_label_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
            JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id
            JOIN classification_trees ON classification_trees.classification_alias_id = ANY (
              classification_alias_paths_transitive.full_path_ids
            )
            AND classification_trees.deleted_at IS NULL
            JOIN classification_alias_paths cap ON cap.id = classification_trees.classification_alias_id
          WHERE classification_trees.classification_alias_id = ANY(ca_ids)
          ORDER BY classification_contents.content_data_id, classification_trees.classification_alias_id, ARRAY_REVERSE(classification_alias_paths_transitive.full_path_ids) ASC
        ),
        new_collected_classification_contents AS (
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
              WHEN full_classification_content_relations.direct THEN 'direct'
              WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'related'
            END AS "link_type"
          FROM full_classification_content_relations
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.id IN (
              SELECT ccc.id
              FROM collected_classification_contents ccc
              WHERE ccc.classification_alias_id = ANY(ca_ids)
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
          link_type
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type
      FROM new_collected_classification_contents ON CONFLICT (thing_id, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type;

      END IF;

      END;

      $$;
    SQL
  end

  def down
  end
end
