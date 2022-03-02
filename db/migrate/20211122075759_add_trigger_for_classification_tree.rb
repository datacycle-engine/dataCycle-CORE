# frozen_string_literal: true

class AddTriggerForClassificationTree < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      DROP TRIGGER update_classification_alias_paths_trigger ON classification_trees;

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF parent_classification_alias_id,
        classification_alias_id,
        classification_tree_label_id ON classification_trees
        FOR EACH ROW
        WHEN (OLD.parent_classification_alias_id <> NEW.parent_classification_alias_id OR OLD.classification_alias_id <> NEW.classification_alias_id OR NEW.classification_tree_label_id <> OLD.classification_tree_label_id)
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_2 ();

      CREATE OR REPLACE FUNCTION generate_classification_alias_paths_trigger_2 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_classification_alias_paths (array_agg(id) || NEW.classification_alias_id)
        FROM (
          SELECT
            id
          FROM
            classification_alias_paths
          WHERE
            NEW.classification_alias_id = ANY (ancestor_ids)) "changed_child_classification_aliasese";
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def down
  end
end
