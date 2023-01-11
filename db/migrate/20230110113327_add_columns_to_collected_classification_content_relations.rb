# frozen_string_literal: true

class AddColumnsToCollectedClassificationContentRelations < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TABLE IF EXISTS collected_classification_content_relations;

      CREATE TABLE collected_classification_contents (
        thing_id UUID NOT NULL PRIMARY KEY REFERENCES things(id) ON DELETE CASCADE,
        direct_classification_alias_ids UUID[],
        full_classification_alias_ids UUID[],
        direct_tree_label_ids UUID[],
        full_tree_label_ids UUID[]
      );

      CREATE INDEX IF NOT EXISTS ccc_direct_tree_label_ids_idx ON collected_classification_contents USING gin(direct_tree_label_ids);
      CREATE INDEX IF NOT EXISTS ccc_full_tree_label_ids_idx ON collected_classification_contents USING gin(full_tree_label_ids);
      CREATE INDEX IF NOT EXISTS ccc_direct_classification_alias_ids_idx ON collected_classification_contents USING gin(direct_classification_alias_ids);
      CREATE INDEX IF NOT EXISTS ccc_full_classification_alias_ids_idx ON collected_classification_contents USING gin(full_classification_alias_ids);

       CREATE INDEX IF NOT EXISTS capt_classification_alias_id_idx ON classification_alias_paths_transitive(classification_alias_id);

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
    SQL
  end

  def down
    execute <<-SQL.squish
      CREATE TABLE collected_classification_content_relations (
        id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
        content_id uuid,
        direct_classification_alias_ids uuid[],
        full_classification_alias_ids uuid[]
      );

      DROP FUNCTION IF EXISTS generate_collected_classification_content_relations;

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations (content_ids uuid[], excluded_classification_ids uuid[])
        RETURNS uuid[]
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM collected_classification_content_relations
        WHERE content_id IN (
          SELECT cccr.content_id FROM collected_classification_content_relations cccr
          WHERE cccr.content_id = ANY (content_ids)
          ORDER BY cccr.content_id ASC
          FOR UPDATE SKIP LOCKED
        );
        WITH direct_classification_content_relations AS (
          SELECT DISTINCT
            things.id "thing_id",
            classification_groups.classification_alias_id "classification_alias_id"
          FROM
            things
            JOIN classification_contents ON things.id = classification_contents.content_data_id
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
          WHERE
            things.id = ANY (content_ids)
            AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      ),
      full_classification_content_relations AS (
        SELECT DISTINCT
          things.id "thing_id",
          UNNEST(classification_alias_paths.full_path_ids) "classification_alias_id"
        FROM
          things
          JOIN classification_contents ON things.id = classification_contents.content_data_id
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
        WHERE
          things.id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids))
      INSERT INTO collected_classification_content_relations (content_id, direct_classification_alias_ids, full_classification_alias_ids)
      SELECT
        things.id "content_id",
        direct_content_classification_ids "direct_classification_alias_ids",
        full_content_classification_ids "full_classification_alias_ids"
      FROM
        things
        JOIN (
          SELECT
            thing_id,
            ARRAY_AGG(direct_classification_content_relations.classification_alias_id) "direct_content_classification_ids"
          FROM
            direct_classification_content_relations
          GROUP BY
            thing_id) "direct_relations" ON direct_relations.thing_id = things.id
        JOIN (
          SELECT
            thing_id,
            ARRAY_AGG(full_classification_content_relations.classification_alias_id) "full_content_classification_ids"
          FROM
            full_classification_content_relations
          GROUP BY
            thing_id) "full_relations" ON full_relations.thing_id = things.id;
        RETURN content_ids;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive (content_ids UUID[], excluded_classification_ids UUID[]) RETURNS SETOF UUID LANGUAGE PLPGSQL AS $$
      BEGIN
        DELETE FROM collected_classification_content_relations
        WHERE content_id IN (
          SELECT cccr.content_id FROM collected_classification_content_relations cccr
          WHERE cccr.content_id = ANY (content_ids)
          ORDER BY cccr.content_id ASC
          FOR UPDATE SKIP LOCKED
        );
        RETURN QUERY WITH direct_classification_content_relations AS (
          SELECT DISTINCT
            classification_contents.content_data_id "thing_id",
            classification_groups.classification_alias_id "classification_alias_id"
          FROM
            classification_contents
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
          WHERE
            classification_contents.content_data_id = ANY (content_ids)
            AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      ),
      full_classification_content_relations AS (
        SELECT DISTINCT
          classification_contents.content_data_id "thing_id",
          classification_alias_paths_transitive.full_path_ids "classification_alias_id"
        FROM
          classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id =
            classification_alias_paths_transitive.classification_alias_id
        WHERE
          classification_contents.content_data_id = ANY (content_ids)
          AND classification_contents.classification_id <> ALL (excluded_classification_ids))
      INSERT INTO collected_classification_content_relations (
        content_id,
        direct_classification_alias_ids,
        full_classification_alias_ids)
      SELECT
        things.id "content_id",
        direct_content_classification_ids "direct_classification_alias_ids",
        full_content_classification_ids "full_classification_alias_ids"
      FROM
        things
        JOIN (
          SELECT
            thing_id,
            ARRAY_AGG(DISTINCT direct_classification_content_relations.classification_alias_id) "direct_content_classification_ids"
          FROM
            direct_classification_content_relations
          GROUP BY
            thing_id) "direct_relations" ON direct_relations.thing_id = things.id
        JOIN (
          SELECT
            t.thing_id,
            ARRAY_AGG(t.classification_alias_id) "full_content_classification_ids"
          FROM ( SELECT DISTINCT
              unnest(full_classification_content_relations.classification_alias_id) AS classification_alias_id,
              full_classification_content_relations.thing_id AS thing_id
            FROM
              full_classification_content_relations) t
          GROUP BY
            t.thing_id) "full_relations" ON full_relations.thing_id = things.id
      RETURNING
        content_id;
        RETURN;
      END;
      $$;

      DROP INDEX IF EXISTS cccr_direct_tree_label_ids_idx;
      DROP INDEX IF EXISTS cccr_full_tree_label_ids_idx;
      DROP INDEX IF EXISTS ccc_direct_classification_alias_ids_idx;
      DROP INDEX IF EXISTS ccc_full_classification_alias_ids_idx;

      DROP TABLE IF EXISTS collected_classification_contents;

      DROP INDEX IF EXISTS cccr_content_id_direct_classification_alias_ids_idx;
      DROP INDEX IF EXISTS cccr_content_id_full_classification_alias_ids_idx;
      DROP INDEX IF EXISTS cccr_content_id_direct_tree_label_ids_idx;
      DROP INDEX IF EXISTS cccr_content_id_full_tree_label_ids_idx;

      ALTER TABLE collected_classification_content_relations DROP COLUMN direct_tree_label_ids;
      ALTER TABLE collected_classification_content_relations DROP COLUMN full_tree_label_ids;

      DROP INDEX IF EXISTS capt_classification_alias_id_idx;
    SQL
  end
end
