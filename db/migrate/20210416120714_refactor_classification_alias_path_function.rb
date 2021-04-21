# frozen_string_literal: true

class RefactorClassificationAliasPathFunction < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION generate_classification_alias_paths(classification_alias_ids UUID[]) RETURNS UUID[] LANGUAGE PLPGSQL AS $$
      DECLARE
        classification_alias_path_ids UUID[];
      BEGIN
        DELETE FROM classification_alias_paths WHERE id = ANY(classification_alias_ids);

        WITH RECURSIVE paths( id, parent_id,ancestor_ids,full_path_ids,full_path_names, tree_label_id) AS
        (
            SELECT
              classification_aliases.id,
              classification_trees.parent_classification_alias_id,
              ARRAY[]::uuid[],
              ARRAY[classification_aliases.id],
              ARRAY[classification_aliases.internal_name],
              classification_trees.classification_tree_label_id
            FROM
              classification_trees
            JOIN classification_aliases
             ON classification_aliases.id = classification_trees.classification_alias_id
            WHERE classification_trees.classification_alias_id = ANY(classification_alias_ids)
                UNION ALL
            SELECT
              paths.id,
              classification_trees.parent_classification_alias_id,
              ancestor_ids || classification_aliases.id,
              full_path_ids || classification_aliases.id ,
              full_path_names || classification_aliases.internal_name,
              classification_trees.classification_tree_label_id
            FROM
              classification_trees
            JOIN paths
             ON paths.parent_id = classification_trees.classification_alias_id
            JOIN classification_aliases
             ON classification_aliases.id = classification_trees.classification_alias_id
        ) INSERT INTO classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names)
        SELECT
          paths.id, paths.ancestor_ids, paths.full_path_ids, paths.full_path_names || classification_tree_labels.name
        FROM
          paths
        JOIN classification_tree_labels
        ON classification_tree_labels.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL;

        SELECT ARRAY_AGG(id) INTO classification_alias_path_ids
        FROM classification_alias_paths WHERE id = ANY(classification_alias_ids);

        RETURN classification_alias_path_ids;
      END;$$;
    SQL
    execute('VACUUM classification_alias_paths;')
    execute('ANALYZE classification_alias_paths;')
  end

  def down
  end
end
