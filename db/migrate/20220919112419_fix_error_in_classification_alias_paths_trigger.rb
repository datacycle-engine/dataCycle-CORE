# frozen_string_literal: true

class FixErrorInClassificationAliasPathsTrigger < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION generate_classification_alias_paths_trigger_1 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_classification_alias_paths (array_agg(id) || ARRAY[NEW.id]::UUID[])
        FROM (
          SELECT
            id
          FROM
            classification_alias_paths
          WHERE
            NEW.id = ANY (ancestor_ids)) "new_child_classification_aliases";
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_classification_alias_paths_trigger_2 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_classification_alias_paths (array_agg(id) || ARRAY[NEW.classification_alias_id]::UUID[])
        FROM (
          SELECT
            id
          FROM
            classification_alias_paths
          WHERE
            NEW.classification_alias_id = ANY (ancestor_ids)) "changed_child_classification_aliases";
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_classification_alias_paths_trigger_3 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_classification_alias_paths (array_agg(classification_alias_id))
        FROM (
          SELECT
            classification_alias_id
          FROM
            classification_trees
          WHERE
            classification_trees.classification_tree_label_id = NEW.id) "changed_tree_classification_aliases";
        RETURN NEW;
      END;
      $$;
    SQL
  end

  def down
  end
end
