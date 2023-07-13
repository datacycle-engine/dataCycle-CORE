# frozen_string_literal: true

class RefactorSomeTriggersForCollectedClassificationContents < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS generate_collected_classification_content_relations_trigger ON classification_alias_paths;

      CREATE TRIGGER update_collected_classification_content_relations_trigger
      AFTER
      UPDATE ON classification_alias_paths FOR EACH ROW EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_3();

      CREATE FUNCTION generate_collected_classification_content_relations_trigger_5() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_collected_classification_content_relations (ARRAY_AGG(content_data_id), ARRAY []::uuid [])
      FROM (
          SELECT DISTINCT classification_contents.content_data_id
          FROM new_classification_alias_paths
            INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY (
              new_classification_alias_paths.full_path_ids
            )
            AND classification_groups.deleted_at IS NULL
            INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id
        ) "collected_classification_content_relations_alias";

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger
      AFTER
      INSERT ON classification_alias_paths REFERENCING NEW TABLE AS new_classification_alias_paths FOR EACH STATEMENT EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_5();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS generate_collected_classification_content_relations_trigger ON classification_alias_paths;
      DROP TRIGGER IF EXISTS update_collected_classification_content_relations_trigger ON classification_alias_paths;

      DROP FUNCTION IF EXISTS generate_collected_classification_content_relations_trigger_5;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger
      AFTER
      INSERT
        OR
      UPDATE ON classification_alias_paths FOR EACH ROW EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_3();
    SQL
  end
end
