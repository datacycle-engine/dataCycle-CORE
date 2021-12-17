# frozen_string_literal: true

class FixTriggersForNullValues < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      DROP TRIGGER update_classification_alias_paths_trigger ON classification_trees;

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF parent_classification_alias_id,
        classification_alias_id,
        classification_tree_label_id ON classification_trees
        FOR EACH ROW
        WHEN (OLD.parent_classification_alias_id IS DISTINCT FROM NEW.parent_classification_alias_id OR
          OLD.classification_alias_id IS DISTINCT FROM NEW.classification_alias_id OR NEW.classification_tree_label_id IS
          DISTINCT FROM OLD.classification_tree_label_id)
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_2 ();

      DROP TRIGGER update_collected_classification_content_relations_trigger_1 ON classification_contents;

      CREATE TRIGGER update_collected_classification_content_relations_trigger_1
        AFTER UPDATE OF content_data_id,
        classification_id,
        relation ON classification_contents
        FOR EACH ROW
        WHEN (OLD.content_data_id IS DISTINCT FROM NEW.content_data_id OR OLD.classification_id IS DISTINCT FROM
          NEW.classification_id OR OLD.relation IS DISTINCT FROM NEW.relation)
        EXECUTE FUNCTION generate_collected_classification_content_relations_trigger_1 ();

      DROP TRIGGER update_collected_classification_content_relations_trigger_4 ON classification_groups;

      CREATE TRIGGER update_collected_classification_content_relations_trigger_4
        AFTER UPDATE OF deleted_at ON classification_groups
        FOR EACH ROW
        WHEN (OLD.deleted_at IS DISTINCT FROM NEW.deleted_at)
        EXECUTE FUNCTION delete_collected_classification_content_relations_trigger_1 ();

      DROP TRIGGER update_classification_alias_paths_trigger ON classification_tree_labels;

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF name ON classification_tree_labels
        FOR EACH ROW
        WHEN (OLD.name IS DISTINCT FROM NEW.name)
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_3 ();

      DROP TRIGGER update_classification_alias_paths_trigger ON classification_trees;

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF parent_classification_alias_id,
        classification_alias_id,
        classification_tree_label_id ON classification_trees
        FOR EACH ROW
        WHEN (OLD.parent_classification_alias_id IS DISTINCT FROM NEW.parent_classification_alias_id OR
          OLD.classification_alias_id IS DISTINCT FROM NEW.classification_alias_id OR NEW.classification_tree_label_id IS
          DISTINCT FROM OLD.classification_tree_label_id)
        EXECUTE FUNCTION generate_classification_alias_paths_trigger_2 ();

      DROP TRIGGER update_content_content_links_trigger ON content_contents;

      CREATE TRIGGER update_content_content_links_trigger
        AFTER UPDATE OF content_a_id,
        content_b_id,
        relation_b ON content_contents
        FOR EACH ROW
        WHEN (OLD.content_a_id IS DISTINCT FROM NEW.content_a_id OR OLD.content_b_id IS DISTINCT FROM NEW.content_b_id OR
          OLD.relation_b IS DISTINCT FROM NEW.relation_b)
        EXECUTE FUNCTION generate_content_content_links_trigger ();

      DROP TRIGGER update_schedule_occurences_trigger ON schedules;

      CREATE TRIGGER update_schedule_occurences_trigger
        AFTER UPDATE OF thing_id,
        duration,
        rrule,
        dtstart,
        relation,
        exdate,
        rdate ON schedules
        FOR EACH ROW
        WHEN (OLD.thing_id IS DISTINCT FROM NEW.thing_id OR OLD.duration IS DISTINCT FROM NEW.duration OR OLD.rrule IS
          DISTINCT FROM NEW.rrule OR OLD.dtstart IS DISTINCT FROM NEW.dtstart OR OLD.relation IS DISTINCT FROM NEW.relation
          OR OLD.rdate IS DISTINCT FROM NEW.rdate OR OLD.exdate IS DISTINCT FROM NEW.exdate)
        EXECUTE FUNCTION generate_schedule_occurences_trigger ();

      DROP TRIGGER tsvectorsearchupdate ON searches;

      CREATE TRIGGER tsvectorsearchupdate
        BEFORE UPDATE OF words,
        locale,
        full_text ON searches
        FOR EACH ROW
        WHEN (OLD.words IS DISTINCT FROM NEW.words OR OLD.locale IS DISTINCT FROM NEW.locale OR OLD.full_text IS DISTINCT
          FROM NEW.full_text)
        EXECUTE FUNCTION tsvectorsearchupdate ();

      DROP TRIGGER tsvectortypeaheadsearchupdate ON searches;

      CREATE TRIGGER tsvectortypeaheadsearchupdate
        BEFORE UPDATE OF full_text ON searches
        FOR EACH ROW
        WHEN (OLD.full_text IS DISTINCT FROM NEW.full_text)
        EXECUTE PROCEDURE tsvector_update_trigger (words_typeahead, 'pg_catalog.simple', full_text);

      DROP TRIGGER update_classification_alias_paths_trigger ON classification_aliases;

      CREATE TRIGGER update_classification_alias_paths_trigger
        AFTER UPDATE OF internal_name ON classification_aliases
        FOR EACH ROW
        WHEN (OLD.internal_name IS DISTINCT FROM NEW.internal_name)
        EXECUTE PROCEDURE generate_classification_alias_paths_trigger_1 ();
    SQL
  end

  def down
  end
end
