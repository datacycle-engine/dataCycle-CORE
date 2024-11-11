# frozen_string_literal: true

class FixClassificationTreeOrderATriggerFunction < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.update_classification_trees_order_a_trigger() RETURNS TRIGGER LANGUAGE 'plpgsql' COST 100 VOLATILE NOT LEAKPROOF AS $BODY$ BEGIN PERFORM public.reset_classification_aliases_order_a(ARRAY_AGG(classification_alias_id))
      FROM (
          SELECT new_classification_trees.classification_alias_id
          FROM new_classification_trees
            INNER JOIN old_classification_trees ON old_classification_trees.id = new_classification_trees.id
          WHERE new_classification_trees.deleted_at IS NULL
            AND (
              new_classification_trees.parent_classification_alias_id IS DISTINCT
              FROM old_classification_trees.parent_classification_alias_id
                OR new_classification_trees.classification_tree_label_id IS DISTINCT
              FROM old_classification_trees.classification_tree_label_id
            )
        ) "reset_classification_trees_alias";

      PERFORM public.update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
      FROM (
          SELECT DISTINCT new_classification_trees.classification_tree_label_id
          FROM new_classification_trees
            INNER JOIN old_classification_trees ON old_classification_trees.id = new_classification_trees.id
            INNER JOIN classification_aliases ON classification_aliases.id = new_classification_trees.classification_alias_id
            AND classification_aliases.deleted_at IS NULL
          WHERE new_classification_trees.deleted_at IS NULL
            AND (
              new_classification_trees.parent_classification_alias_id IS DISTINCT
              FROM old_classification_trees.parent_classification_alias_id
                OR new_classification_trees.classification_tree_label_id IS DISTINCT
              FROM old_classification_trees.classification_tree_label_id
            )
        ) "updated_classification_trees_alias";

      RETURN NULL;

      END;

      $BODY$;
    SQL
  end

  def down
  end
end
