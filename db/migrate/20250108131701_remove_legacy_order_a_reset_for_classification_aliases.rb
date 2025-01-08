# frozen_string_literal: true

class RemoveLegacyOrderAResetForClassificationAliases < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION public.update_classification_trees_order_a_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM public.update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
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

      $$;

      CREATE OR REPLACE FUNCTION public.insert_classification_trees_order_a_trigger() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
      FROM (
          SELECT DISTINCT new_classification_trees.classification_tree_label_id
          FROM new_classification_trees
        ) "new_classification_trees_alias";

      RETURN NULL;

      END;

      $$;

      DROP FUNCTION IF EXISTS public.reset_classification_aliases_order_a(classification_alias_ids uuid[]);
    SQL
  end

  def down
  end
end
