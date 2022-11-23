# frozen_string_literal: true

class AddOrderToDeadLockPreventionInCollectedClassificationContentRelations < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
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
    SQL
  end

  def down
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations (content_ids uuid[], excluded_classification_ids uuid[])
        RETURNS uuid[]
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM collected_classification_content_relations
        WHERE content_id IN (
          SELECT cccr.content_id FROM collected_classification_content_relations cccr
          WHERE cccr.content_id = ANY (content_ids) FOR UPDATE SKIP LOCKED
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
    SQL
  end
end
