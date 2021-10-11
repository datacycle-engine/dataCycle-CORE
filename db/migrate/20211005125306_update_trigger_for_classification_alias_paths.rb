# frozen_string_literal: true

class UpdateTriggerForClassificationAliasPaths < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_aliases;

      CREATE TRIGGER generate_classification_alias_paths_trigger
        AFTER INSERT ON classification_aliases
        FOR EACH ROW
        EXECUTE PROCEDURE generate_classification_alias_paths_trigger_1();

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF internal_name ON classification_aliases
        FOR EACH ROW
        WHEN (OLD.internal_name <> NEW.internal_name)
        EXECUTE PROCEDURE generate_classification_alias_paths_trigger_1();

      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_trees;

      CREATE TRIGGER generate_classification_alias_paths_trigger
        AFTER INSERT ON classification_trees
        FOR EACH ROW
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_2();

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF parent_classification_alias_id, classification_alias_id ON classification_trees
        FOR EACH ROW
        WHEN (OLD.parent_classification_alias_id <> NEW.parent_classification_alias_id OR OLD.classification_alias_id <> NEW.classification_alias_id)
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_2();

      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_tree_labels;

      CREATE TRIGGER generate_classification_alias_paths_trigger
        AFTER INSERT ON classification_tree_labels
        FOR EACH ROW
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_3();

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF name ON classification_tree_labels
        FOR EACH ROW
        WHEN (OLD.name <> NEW.name)
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_3();

      DROP TRIGGER generate_collected_classification_content_relations_trigger_1 ON classification_contents;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger_1
        AFTER INSERT ON classification_contents
        FOR EACH ROW
        EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_1();

      CREATE TRIGGER update_collected_classification_content_relations_trigger_1
        AFTER UPDATE OF content_data_id, classification_id, relation ON classification_contents
        FOR EACH ROW
        WHEN (OLD.content_data_id <> NEW.content_data_id OR OLD.classification_id <> NEW.classification_id OR OLD.relation <> NEW.relation)
        EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_1();
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_aliases;
      DROP TRIGGER update_classification_alias_paths_trigger ON classification_aliases;

      CREATE TRIGGER generate_classification_alias_paths_trigger
        AFTER INSERT OR UPDATE ON classification_aliases
        FOR EACH ROW
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_1();

      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_trees;
      DROP TRIGGER update_classification_alias_paths_trigger ON classification_trees;

      CREATE TRIGGER generate_classification_alias_paths_trigger
        AFTER INSERT OR UPDATE ON classification_trees
        FOR EACH ROW
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_2();

      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_tree_labels;
      DROP TRIGGER update_classification_alias_paths_trigger ON classification_tree_labels;

      CREATE TRIGGER generate_classification_alias_paths_trigger
        AFTER INSERT OR UPDATE ON classification_tree_labels
        FOR EACH ROW
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_3();

      DROP TRIGGER generate_collected_classification_content_relations_trigger_1 ON classification_contents;
      DROP TRIGGER update_collected_classification_content_relations_trigger_1 ON classification_contents;

      CREATE TRIGGER generate_collected_classification_content_relations_trigger_1
        AFTER INSERT OR UPDATE ON classification_contents
        FOR EACH ROW
        EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_1();

    SQL
  end
end
