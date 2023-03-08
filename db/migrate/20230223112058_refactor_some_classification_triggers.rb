# frozen_string_literal: true

class RefactorSomeClassificationTriggers < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS update_ccc_relations_transitive_trigger ON classification_groups;
      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER update_deleted_at_ccc_relations_transitive_trigger
      AFTER
      UPDATE OF deleted_at ON classification_groups FOR EACH ROW
        WHEN (
          OLD.deleted_at IS NULL
          AND NEW.deleted_at IS NOT NULL
        ) EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1 ();

      CREATE OR REPLACE FUNCTION update_ca_paths_transitive_trigger_4 () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN PERFORM generate_ca_paths_transitive (
          ARRAY [OLD.classification_alias_id, NEW.classification_alias_id]::uuid []
        );
      RETURN NEW;
      END;
      $$;

      ALTER TABLE classification_groups DISABLE TRIGGER update_deleted_at_ccc_relations_transitive_trigger;

      CREATE TRIGGER update_ccc_relations_transitive_trigger
      AFTER
      UPDATE OF classification_id,
        classification_alias_id ON classification_groups FOR EACH ROW
        WHEN (
          OLD.classification_id IS DISTINCT
          FROM NEW.classification_id
            OR OLD.classification_alias_id IS DISTINCT
          FROM NEW.classification_alias_id
        ) EXECUTE FUNCTION update_ca_paths_transitive_trigger_4 ();

      ALTER TABLE classification_groups DISABLE TRIGGER update_ccc_relations_transitive_trigger;

      DROP TRIGGER IF EXISTS update_collected_classification_content_relations_trigger_4 ON classification_groups;
      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_trigger_4 ON classification_groups;

      CREATE TRIGGER update_deleted_at_ccc_relations_trigger_4
      AFTER
      UPDATE OF deleted_at ON classification_groups FOR EACH ROW
        WHEN (
          OLD.deleted_at IS NULL
          AND NEW.deleted_at IS NOT NULL
        ) EXECUTE FUNCTION delete_collected_classification_content_relations_trigger_1 ();

      CREATE OR REPLACE FUNCTION update_collected_classification_content_relations_trigger_4 () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN PERFORM generate_collected_classification_content_relations (
          (
            SELECT ARRAY_AGG(DISTINCT things.id)
            FROM things
              JOIN classification_contents ON things.id = classification_contents.content_data_id
              JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
            WHERE classification_groups.classification_id IN (NEW.classification_id, OLD.classification_id)),
              ARRAY []::uuid []
          );
      RETURN NEW;
      END;
      $$;

      DROP TRIGGER IF EXISTS update_ccc_relations_trigger_4 ON classification_groups;

      CREATE TRIGGER update_ccc_relations_trigger_4
      AFTER
      UPDATE OF classification_id,
        classification_alias_id ON classification_groups FOR EACH ROW
        WHEN (
          OLD.classification_id IS DISTINCT
          FROM NEW.classification_id
            OR OLD.classification_alias_id IS DISTINCT
          FROM NEW.classification_alias_id
        ) EXECUTE FUNCTION update_collected_classification_content_relations_trigger_4();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_transitive_trigger ON classification_groups;

      DROP TRIGGER IF EXISTS update_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER update_ccc_relations_transitive_trigger
      AFTER
      UPDATE OF deleted_at ON classification_groups FOR EACH ROW
        WHEN (
          OLD.deleted_at IS NULL
          AND NEW.deleted_at IS NOT NULL
        ) EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1 ();

      ALTER TABLE classification_groups DISABLE TRIGGER update_ccc_relations_transitive_trigger;

      DROP FUNCTION IF EXISTS update_ca_paths_transitive_trigger_4;

      DROP TRIGGER IF EXISTS update_ccc_relations_trigger_4 ON classification_groups;

      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_trigger_4 ON classification_groups;

      CREATE TRIGGER update_collected_classification_content_relations_trigger_4
      AFTER
      UPDATE OF deleted_at ON classification_groups FOR EACH ROW
        WHEN (
          OLD.deleted_at IS DISTINCT
          FROM NEW.deleted_at
        ) EXECUTE FUNCTION delete_collected_classification_content_relations_trigger_1 ();

      DROP FUNCTION IF EXISTS update_collected_classification_content_relations_trigger_4;
    SQL
  end
end
