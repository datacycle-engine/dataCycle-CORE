# frozen_string_literal: true

class FixGenerateCollectedClassificationContentRelationsTriggerWithUpsert < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS generate_collected_classification_content_relations;

      CREATE
      OR REPLACE FUNCTION generate_collected_classification_content_relations (content_ids UUID[], excluded_classification_ids UUID[]) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
        DELETE FROM collected_classification_contents
        WHERE
          thing_id IN (
            SELECT
              cccr.thing_id
            FROM
              collected_classification_contents cccr
            WHERE
              cccr.thing_id = ANY (content_ids)
            ORDER BY
              cccr.thing_id ASC FOR
            UPDATE SKIP LOCKED
          );

        WITH
          direct_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT classification_groups.classification_alias_id) "direct_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "direct_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
              AND classification_trees.deleted_at IS NULL
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          ),
          full_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT a.e) "full_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "full_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
              JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths.full_path_ids)
              AND classification_trees.deleted_at IS NULL
              CROSS JOIN LATERAL UNNEST(classification_alias_paths.full_path_ids) AS a (e)
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          )
        INSERT INTO
          collected_classification_contents (thing_id, direct_classification_alias_ids, full_classification_alias_ids, direct_tree_label_ids, full_tree_label_ids)
        SELECT
          direct_classification_content_relations.thing_id,
          direct_classification_content_relations.direct_alias_ids,
          full_classification_content_relations.full_alias_ids,
          direct_classification_content_relations.direct_tree_label_ids,
          full_classification_content_relations.full_tree_label_ids
        FROM
          direct_classification_content_relations
          JOIN full_classification_content_relations ON full_classification_content_relations.thing_id = direct_classification_content_relations.thing_id ON CONFLICT (thing_id)
        DO
        UPDATE
        SET
          direct_classification_alias_ids = EXCLUDED.direct_classification_alias_ids,
          full_classification_alias_ids = EXCLUDED.full_classification_alias_ids,
          direct_tree_label_ids = EXCLUDED.direct_tree_label_ids,
          full_tree_label_ids = EXCLUDED.full_tree_label_ids;

        RETURN;
      END;
      $$;

      DROP FUNCTION IF EXISTS generate_collected_cl_content_relations_transitive;

      CREATE
      OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive (content_ids UUID[], excluded_classification_ids UUID[]) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
        DELETE FROM collected_classification_contents
        WHERE
          thing_id IN (
            SELECT
              cccr.thing_id
            FROM
              collected_classification_contents cccr
            WHERE
              cccr.thing_id = ANY (content_ids)
            ORDER BY
              cccr.thing_id ASC FOR
            UPDATE SKIP LOCKED
          );

        WITH
          direct_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT classification_groups.classification_alias_id) "direct_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "direct_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
              AND classification_trees.deleted_at IS NULL
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          ),
          full_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT a.e) "full_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "full_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id
              JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths_transitive.full_path_ids)
              AND classification_trees.deleted_at IS NULL
              CROSS JOIN LATERAL UNNEST(classification_alias_paths_transitive.full_path_ids) AS a (e)
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          )
        INSERT INTO
          collected_classification_contents (thing_id, direct_classification_alias_ids, full_classification_alias_ids, direct_tree_label_ids, full_tree_label_ids)
        SELECT
          direct_classification_content_relations.thing_id,
          direct_classification_content_relations.direct_alias_ids,
          full_classification_content_relations.full_alias_ids,
          direct_classification_content_relations.direct_tree_label_ids,
          full_classification_content_relations.full_tree_label_ids
        FROM
          direct_classification_content_relations
          JOIN full_classification_content_relations ON full_classification_content_relations.thing_id = direct_classification_content_relations.thing_id ON CONFLICT (thing_id)
        DO
        UPDATE
        SET
          direct_classification_alias_ids = EXCLUDED.direct_classification_alias_ids,
          full_classification_alias_ids = EXCLUDED.full_classification_alias_ids,
          direct_tree_label_ids = EXCLUDED.direct_tree_label_ids,
          full_tree_label_ids = EXCLUDED.full_tree_label_ids;

        RETURN;
      END;
      $$;

      ALTER TABLE classification_groups ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE classification_groups ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();

      DELETE FROM classification_groups c1
      WHERE
        c1.id NOT IN (
          SELECT DISTINCT
            ON (c2.classification_alias_id, c2.classification_id) c2.id
          FROM
            classification_groups c2
        )
        AND c1.deleted_at IS NULL;

      CREATE UNIQUE INDEX IF NOT EXISTS classification_groups_ca_id_c_id_uq_idx ON classification_groups (classification_alias_id, classification_id)
      WHERE
        classification_groups.deleted_at IS NULL;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS generate_collected_classification_content_relations;

      CREATE
      OR REPLACE FUNCTION generate_collected_classification_content_relations (content_ids UUID[], excluded_classification_ids UUID[]) RETURNS SETOF UUID LANGUAGE PLPGSQL AS $$ BEGIN
        DELETE FROM collected_classification_contents
        WHERE
          thing_id IN (
            SELECT
              cccr.thing_id
            FROM
              collected_classification_contents cccr
            WHERE
              cccr.thing_id = ANY (content_ids)
            ORDER BY
              cccr.thing_id ASC FOR
            UPDATE SKIP LOCKED
          );

        RETURN query
        WITH
          direct_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT classification_groups.classification_alias_id) "direct_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "direct_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
              AND classification_trees.deleted_at IS NULL
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          ),
          full_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT a.e) "full_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "full_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
              JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths.full_path_ids)
              AND classification_trees.deleted_at IS NULL
              CROSS JOIN LATERAL UNNEST(classification_alias_paths.full_path_ids) AS a (e)
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          )
        INSERT INTO
          collected_classification_contents (thing_id, direct_classification_alias_ids, full_classification_alias_ids, direct_tree_label_ids, full_tree_label_ids)
        SELECT
          direct_classification_content_relations.thing_id,
          direct_classification_content_relations.direct_alias_ids,
          full_classification_content_relations.full_alias_ids,
          direct_classification_content_relations.direct_tree_label_ids,
          full_classification_content_relations.full_tree_label_ids
        FROM
          direct_classification_content_relations
          JOIN full_classification_content_relations ON full_classification_content_relations.thing_id = direct_classification_content_relations.thing_id
        RETURNING
          thing_id;

        RETURN;
      END;
      $$;

      DROP FUNCTION IF EXISTS generate_collected_cl_content_relations_transitive;

      CREATE
      OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive (content_ids UUID[], excluded_classification_ids UUID[]) RETURNS SETOF UUID LANGUAGE PLPGSQL AS $$ BEGIN
        DELETE FROM collected_classification_contents
        WHERE
          thing_id IN (
            SELECT
              cccr.thing_id
            FROM
              collected_classification_contents cccr
            WHERE
              cccr.thing_id = ANY (content_ids)
            ORDER BY
              cccr.thing_id ASC FOR
            UPDATE SKIP LOCKED
          );

        RETURN query
        WITH
          direct_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT classification_groups.classification_alias_id) "direct_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "direct_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_trees ON classification_trees.classification_alias_id = classification_groups.classification_alias_id
              AND classification_trees.deleted_at IS NULL
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          ),
          full_classification_content_relations AS (
            SELECT
              classification_contents.content_data_id "thing_id",
              ARRAY_AGG(DISTINCT a.e) "full_alias_ids",
              ARRAY_AGG(DISTINCT classification_trees.classification_tree_label_id) "full_tree_label_ids"
            FROM
              classification_contents
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
              JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = classification_alias_paths_transitive.classification_alias_id
              JOIN classification_trees ON classification_trees.classification_alias_id = ANY (classification_alias_paths_transitive.full_path_ids)
              AND classification_trees.deleted_at IS NULL
              CROSS JOIN LATERAL UNNEST(classification_alias_paths_transitive.full_path_ids) AS a (e)
            WHERE
              classification_contents.content_data_id = ANY (content_ids)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
            GROUP BY
              classification_contents.content_data_id
          )
        INSERT INTO
          collected_classification_contents (thing_id, direct_classification_alias_ids, full_classification_alias_ids, direct_tree_label_ids, full_tree_label_ids)
        SELECT
          direct_classification_content_relations.thing_id,
          direct_classification_content_relations.direct_alias_ids,
          full_classification_content_relations.full_alias_ids,
          direct_classification_content_relations.direct_tree_label_ids,
          full_classification_content_relations.full_tree_label_ids
        FROM
          direct_classification_content_relations
          JOIN full_classification_content_relations ON full_classification_content_relations.thing_id = direct_classification_content_relations.thing_id
        RETURNING
          thing_id;

        RETURN;
      END;
      $$;

      DROP INDEX IF EXISTS classification_groups_ca_id_c_id_uq_idx;

      ALTER TABLE classification_groups ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE classification_groups ALTER COLUMN updated_at DROP DEFAULT;
    SQL
  end
end
