# frozen_string_literal: true

class UpdateFunctionForCollectedClassificationContentRelations < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations (content_ids uuid[], excluded_classification_ids uuid[])
        RETURNS uuid[]
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM collected_classification_content_relations
        WHERE content_id = ANY (content_ids);
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

      SELECT
        generate_collected_classification_content_relations (ARRAY_AGG(id), ARRAY[]::uuid[])
      FROM
        things;

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations_trigger_4 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_collected_classification_content_relations (
            (SELECT
              ARRAY_AGG(DISTINCT things.id)
            FROM things
            JOIN classification_contents ON things.id = classification_contents.content_data_id
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
          WHERE
            classification_groups.classification_id = NEW.classification_id), ARRAY[]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION delete_collected_classification_content_relations_trigger_1 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_collected_classification_content_relations (
            (SELECT
              ARRAY_AGG(DISTINCT things.id)
            FROM things
            JOIN classification_contents ON things.id = classification_contents.content_data_id
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
          WHERE
            classification_groups.classification_id = OLD.classification_id), ARRAY[]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger_4
        AFTER INSERT ON classification_groups
        FOR EACH ROW
        EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_4 ();

      CREATE TRIGGER update_collected_classification_content_relations_trigger_4
        AFTER UPDATE OF deleted_at ON classification_groups
        FOR EACH ROW
        WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
        EXECUTE FUNCTION delete_collected_classification_content_relations_trigger_1 ();

      CREATE TRIGGER delete_collected_classification_content_relations_trigger_1
        AFTER DELETE ON classification_groups
        FOR EACH ROW
        EXECUTE FUNCTION delete_collected_classification_content_relations_trigger_1 ();
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER generate_collected_classification_content_relations_trigger_4 ON classification_groups;
      DROP FUNCTION generate_collected_classification_content_relations_trigger_4;
      DROP TRIGGER update_collected_classification_content_relations_trigger_4 ON classification_groups;
      DROP TRIGGER delete_collected_classification_content_relations_trigger_1 ON classification_groups;
      DROP FUNCTION delete_collected_classification_content_relations_trigger_1;
    SQL
  end
end
