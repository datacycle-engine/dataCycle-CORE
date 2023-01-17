# frozen_string_literal: true

class SetInitialOrderForClassificationAliases < ActiveRecord::Migration[6.1]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      UPDATE classification_aliases
      SET
        order_a = w.order_a
      FROM
        (
          WITH RECURSIVE
            paths (id, full_created_at, tree_label_id) AS (
              SELECT
                classification_aliases.id,
                ARRAY[classification_aliases.created_at],
                classification_trees.classification_tree_label_id
              FROM
                classification_trees
                JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
                AND classification_aliases.deleted_at IS NULL
              WHERE
                classification_trees.parent_classification_alias_id IS NULL
                AND classification_trees.deleted_at IS NULL
              UNION
              SELECT
                classification_trees.classification_alias_id,
                full_created_at || classification_aliases.created_at,
                classification_trees.classification_tree_label_id
              FROM
                classification_trees
                JOIN paths ON paths.id = classification_trees.parent_classification_alias_id
                JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
                AND classification_aliases.deleted_at IS NULL
              WHERE
                classification_trees.deleted_at IS NULL
            )
          SELECT
            paths.id,
            (
              ROW_NUMBER() OVER (
                PARTITION BY
                  classification_tree_labels.id
                ORDER BY
                  paths.full_created_at ASC
              )
            ) AS order_a
          FROM
            paths
            JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
        ) w
      WHERE
        w.id = classification_aliases.id;
    SQL
  end

  def down
  end
end
