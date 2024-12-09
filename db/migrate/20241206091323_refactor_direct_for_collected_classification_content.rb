# frozen_string_literal: true

class RefactorDirectForCollectedClassificationContent < ActiveRecord::Migration[7.1]
  def up
    add_column :collected_classification_contents, :link_type, :string, default: 'direct', null: false

    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH direct_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_groups.classification_alias_id
            ) classification_contents.content_data_id "thing_id",
            classification_groups.classification_alias_id "classification_alias_id",
            classification_trees.classification_tree_label_id,
            'direct' "link_type"
          FROM classification_contents
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
            JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
            AND classification_trees.deleted_at IS NULL
          WHERE classification_groups.classification_alias_id = ANY(ca_ids)
        ),
        full_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_trees.classification_alias_id
            ) classification_contents.content_data_id "thing_id",
            classification_trees.classification_alias_id "classification_alias_id",
            classification_trees.classification_tree_label_id,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              classification_trees.classification_tree_label_id,
              classification_alias_paths_transitive.id
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
            direct_classification_content_relations.link_type
          FROM direct_classification_content_relations
          UNION
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
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

      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH direct_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_aliases.id
            ) classification_contents.content_data_id "thing_id",
            classification_aliases.id "classification_alias_id",
            classification_trees.classification_tree_label_id,
            'direct' "link_type"
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
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              classification_trees.classification_tree_label_id,
              classification_alias_paths_transitive.id
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
            direct_classification_content_relations.link_type
          FROM direct_classification_content_relations
          UNION
          SELECT full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            CASE
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

      WITH direct_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_groups.classification_alias_id
          ) classification_contents.content_data_id "thing_id",
          classification_groups.classification_alias_id,
          classification_trees.classification_tree_label_id,
          'direct' "link_type"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
          AND classification_trees.deleted_at IS NULL
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      ),
      full_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_trees.classification_alias_id
          ) classification_contents.content_data_id "thing_id",
          classification_trees.classification_alias_id "classification_alias_id",
          classification_trees.classification_tree_label_id "classification_tree_label_id",
          ROW_NUMBER() over (
            PARTITION by classification_contents.content_data_id,
            classification_trees.classification_tree_label_id,
            classification_alias_paths.id
            ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
          ) AS "row_number"
        FROM classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
          JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths.full_path_ids)
          AND classification_trees.deleted_at IS NULL
          JOIN classification_alias_paths cap ON cap.id = classification_trees.classification_alias_id
        WHERE classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids)
          AND NOT EXISTS (
            SELECT 1
            FROM direct_classification_content_relations dccr
            WHERE dccr.thing_id = classification_contents.content_data_id
              AND dccr.classification_alias_id = classification_trees.classification_alias_id
          )
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type
        )
      SELECT direct_classification_content_relations.thing_id,
        direct_classification_content_relations.classification_alias_id,
        direct_classification_content_relations.classification_tree_label_id,
        direct_classification_content_relations.link_type
      FROM direct_classification_content_relations
      UNION
      SELECT full_classification_content_relations.thing_id,
        full_classification_content_relations.classification_alias_id,
        full_classification_content_relations.classification_tree_label_id,
        CASE
          WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
          ELSE 'related'
        END AS "link_type"
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
      SET LOCAL statement_timeout = 0;

      DROP INDEX IF EXISTS public.ccc_ca_id_t_id_idx;

      CREATE INDEX IF NOT EXISTS ccc_ca_id_t_id_idx ON public.collected_classification_contents USING btree (
        classification_alias_id ASC NULLS LAST,
        thing_id ASC NULLS LAST,
        link_type ASC NULLS LAST
      );

      DROP INDEX IF EXISTS public.ccc_ctl_id_t_id_idx;

      CREATE INDEX IF NOT EXISTS ccc_ctl_id_t_id_idx ON public.collected_classification_contents USING btree (
        classification_tree_label_id ASC NULLS LAST,
        thing_id ASC NULLS LAST,
        link_type ASC NULLS LAST
      );
    SQL
  end

  def down
  end
end
