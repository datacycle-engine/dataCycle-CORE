# frozen_string_literal: true

class CollectedClassificationContentRelations < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      CREATE TABLE collected_classification_content_relations (
        id uuid DEFAULT uuid_generate_v4() NOT NULL,
        content_id UUID,
        direct_classification_alias_ids UUID[],
        full_classification_alias_ids UUID[]
      );

      CREATE INDEX collected_classification_content_relations_content_id
      ON collected_classification_content_relations(content_id);

      CREATE INDEX collected_classification_content_relations_direct_classification_alias_ids
      ON collected_classification_content_relations USING GIN(direct_classification_alias_ids);

      CREATE INDEX collected_classification_content_relations_full_classification_alias_ids
      ON collected_classification_content_relations USING GIN(full_classification_alias_ids);

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations(
        content_ids UUID[],
        excluded_classification_ids UUID[]
      ) RETURNS UUID[] LANGUAGE PLPGSQL AS $$
      BEGIN
        DELETE FROM collected_classification_content_relations WHERE content_id = ANY(content_ids);

        WITH direct_classification_content_relations AS (
          SELECT DISTINCT things.id "thing_id", classification_groups.classification_alias_id "classification_alias_id"
          FROM things
          JOIN classification_contents ON things.id = classification_contents.content_data_id
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          WHERE things.id = ANY(content_ids) AND
            classification_contents.classification_id <> ALL(excluded_classification_ids)
        ), full_classification_content_relations AS (
          SELECT DISTINCT things.id "thing_id", UNNEST(classification_alias_paths.full_path_ids) "classification_alias_id"
          FROM things
          JOIN classification_contents ON things.id = classification_contents.content_data_id
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
          JOIN classification_alias_paths ON classification_groups.classification_alias_id = classification_alias_paths.id
          WHERE things.id = ANY(content_ids) AND
            classification_contents.classification_id <> ALL(excluded_classification_ids)
        )
        INSERT INTO collected_classification_content_relations (
          content_id, direct_classification_alias_ids, full_classification_alias_ids
        ) SELECT
          things.id "content_id",
          direct_content_classification_ids "direct_classification_alias_ids",
          full_content_classification_ids "full_classification_alias_ids"
        FROM things
        JOIN (
          SELECT
            thing_id,
            ARRAY_AGG(direct_classification_content_relations.classification_alias_id) "direct_content_classification_ids"
          FROM direct_classification_content_relations
          GROUP BY thing_id
        ) "direct_relations" ON direct_relations.thing_id = things.id
        JOIN (
          SELECT
            thing_id,
            ARRAY_AGG(full_classification_content_relations.classification_alias_id) "full_content_classification_ids"
          FROM full_classification_content_relations
          GROUP BY thing_id
        ) "full_relations" ON full_relations.thing_id = things.id;

        RETURN content_ids;
      END;$$;

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations_trigger_1()
      RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
        PERFORM generate_collected_classification_content_relations(ARRAY[NEW.content_data_id]::UUID[], ARRAY[]::UUID[]);

        RETURN NEW;
      END;$$;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger_1
      AFTER INSERT OR UPDATE ON classification_contents FOR EACH ROW
      EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_1();

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations_trigger_2()
      RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
        PERFORM generate_collected_classification_content_relations(
          ARRAY[OLD.content_data_id]::UUID[],
          ARRAY[OLD.classification_id]::UUID[]
        );

        RETURN NEW;
      END;$$;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger_2
      AFTER DELETE ON classification_contents FOR EACH ROW
      EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_2();

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations_trigger_3()
      RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
        PERFORM generate_collected_classification_content_relations(ARRAY_AGG(content_id), ARRAY[]::UUID[]) FROM (
          SELECT content_id
          FROM collected_classification_content_relations
          WHERE NEW.id = ANY(direct_classification_alias_ids)
        ) "relevant_content_ids";

        RETURN NEW;
      END;$$;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger
      AFTER INSERT OR UPDATE ON classification_alias_paths FOR EACH ROW
      EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_3();

      SELECT generate_collected_classification_content_relations(ARRAY_AGG(id), ARRAY[]::UUID[]) FROM things;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER generate_collected_classification_content_relations_trigger ON classification_alias_paths;
      DROP FUNCTION generate_collected_classification_content_relations_trigger_3;

      DROP TRIGGER generate_collected_classification_content_relations_trigger_2 ON classification_contents;
      DROP FUNCTION generate_collected_classification_content_relations_trigger_2;

      DROP TRIGGER generate_collected_classification_content_relations_trigger_1 ON classification_contents;
      DROP FUNCTION generate_collected_classification_content_relations_trigger_1;

      DROP FUNCTION generate_collected_classification_content_relations;

      DROP TABLE collected_classification_content_relations;
    SQL
  end
end
