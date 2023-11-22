# frozen_string_literal: true

class RefactorTriggersForClassificationPathsTransitive < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE FUNCTION generate_ca_paths_transitive_statement_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
        ARRAY_AGG(DISTINCT inserted_classification_aliases.id)
      )
      FROM (
          SELECT DISTINCT new_classification_aliases.id
          FROM new_classification_aliases
        ) "inserted_classification_aliases";

      RETURN NULL;

      END;

      $$;

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_aliases;

      CREATE TRIGGER generate_ca_paths_transitive_trigger
      AFTER
      INSERT ON classification_aliases REFERENCING NEW TABLE AS new_classification_aliases FOR EACH STATEMENT EXECUTE FUNCTION generate_ca_paths_transitive_statement_trigger_1 ();

      CREATE FUNCTION generate_ca_paths_transitive_statement_trigger_2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
        ARRAY_AGG(
          DISTINCT inserted_classification_tree_labels.classification_alias_id
        )
      )
      FROM (
          SELECT DISTINCT classification_trees.classification_alias_id
          FROM classification_trees
          WHERE classification_trees.classification_tree_label_id IN (
              SELECT new_classification_tree_labels.id
              FROM new_classification_tree_labels
            )
        ) "inserted_classification_tree_labels";

      RETURN NULL;

      END;

      $$;

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_tree_labels;

      CREATE TRIGGER generate_ca_paths_transitive_trigger
      AFTER
      INSERT ON classification_tree_labels REFERENCING NEW TABLE AS new_classification_tree_labels FOR EACH STATEMENT EXECUTE FUNCTION generate_ca_paths_transitive_statement_trigger_2 ();

      CREATE FUNCTION generate_ca_paths_transitive_statement_trigger_3() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
        ARRAY_AGG(
          DISTINCT inserted_classification_tree_labels.classification_alias_id
        )
      )
      FROM (
          SELECT DISTINCT new_classification_trees.classification_alias_id
          FROM new_classification_trees
        ) "inserted_classification_tree_labels";

      RETURN NULL;

      END;

      $$;

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_trees;

      CREATE TRIGGER generate_ca_paths_transitive_trigger
      AFTER
      INSERT ON classification_trees REFERENCING NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION generate_ca_paths_transitive_statement_trigger_3 ();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_aliases;

      DROP FUNCTION generate_ca_paths_transitive_statement_trigger_1;

      CREATE TRIGGER generate_ca_paths_transitive_trigger
      AFTER
      INSERT ON classification_aliases FOR EACH ROW EXECUTE PROCEDURE generate_ca_paths_transitive_trigger_1 ();

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_tree_labels;

      DROP FUNCTION generate_ca_paths_transitive_statement_trigger_2;

      CREATE TRIGGER generate_ca_paths_transitive_trigger
      AFTER
      INSERT ON classification_tree_labels FOR EACH ROW EXECUTE FUNCTION generate_ca_paths_transitive_trigger_3 ();

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_trees;

      DROP FUNCTION generate_ca_paths_transitive_statement_trigger_3;

      CREATE TRIGGER generate_ca_paths_transitive_trigger
      AFTER
      INSERT ON classification_trees FOR EACH ROW EXECUTE FUNCTION generate_ca_paths_transitive_trigger_2 ();
    SQL
  end
end
