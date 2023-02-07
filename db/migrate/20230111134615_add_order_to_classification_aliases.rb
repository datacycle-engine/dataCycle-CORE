# frozen_string_literal: true

class AddOrderToClassificationAliases < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      ALTER TABLE classification_aliases ADD COLUMN order_a INTEGER;
      ALTER TABLE classification_aliases ALTER COLUMN created_at SET DEFAULT transaction_timestamp();
      ALTER TABLE classification_aliases ALTER COLUMN updated_at SET DEFAULT transaction_timestamp();
      CREATE INDEX IF NOT EXISTS classification_aliases_order_a_idx ON classification_aliases(order_a);

      CREATE OR REPLACE FUNCTION update_classification_aliases_order_a (tree_label_ids UUID[]) RETURNS void LANGUAGE plpgsql AS $$
        BEGIN
        UPDATE classification_aliases
        SET
          order_a = w.order_a
        FROM
          (
            WITH RECURSIVE
              paths (id, updated_at, full_order_a, tree_label_id) AS (
                SELECT
                  classification_aliases.id,
                  classification_aliases.updated_at,
                  ARRAY[
                    (
                      ROW_NUMBER() OVER (
                        PARTITION BY
                          classification_trees.classification_tree_label_id
                        ORDER BY
                          classification_aliases.order_a ASC,
                          classification_aliases.updated_at ASC
                      )
                    )
                  ],
                  classification_trees.classification_tree_label_id
                FROM
                  classification_trees
                  JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
                  AND classification_aliases.deleted_at IS NULL
                WHERE
                  classification_trees.parent_classification_alias_id IS NULL
                  AND classification_trees.deleted_at IS NULL
                  AND classification_trees.classification_tree_label_id = ANY (tree_label_ids)
                UNION
                SELECT
                  classification_trees.classification_alias_id,
                  classification_aliases.updated_at,
                  paths.full_order_a || (
                    ROW_NUMBER() OVER (
                      PARTITION BY
                        classification_trees.classification_tree_label_id
                      ORDER BY
                        paths.full_order_a || classification_aliases.order_a::BIGINT ASC,
                        classification_aliases.updated_at ASC
                    )
                  ),
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
                    paths.full_order_a ASC,
                    paths.updated_at ASC
                )
              ) AS order_a
            FROM
              paths
              JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
          ) w
        WHERE
          w.id = classification_aliases.id;

        END;
      $$;

      CREATE
      OR REPLACE FUNCTION update_classification_aliases_order_a_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
        BEGIN PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
        FROM
          (
            SELECT DISTINCT
              classification_trees.classification_tree_label_id
            FROM
              classification_trees
            WHERE
              classification_trees.classification_alias_id = NEW.id
          ) "updated_classification_aliases_alias";

        RETURN NEW;

        END;
      $$;

      CREATE TRIGGER update_classification_aliases_order_a_trigger
      AFTER UPDATE OF order_a ON classification_aliases FOR EACH ROW WHEN ((OLD.order_a IS DISTINCT FROM NEW.order_a) AND (OLD.updated_at IS DISTINCT FROM NEW.updated_at))
      EXECUTE FUNCTION update_classification_aliases_order_a_trigger ();

      CREATE
      OR REPLACE FUNCTION update_classification_trees_order_a_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
        BEGIN
          UPDATE classification_aliases
          SET order_a = NULL
          WHERE classification_aliases.id = NEW.classification_alias_id
          AND classification_aliases.order_a IS NOT NULL;

          PERFORM update_classification_aliases_order_a (ARRAY[OLD.classification_tree_label_id, NEW.classification_tree_label_id]::UUID[]);
          RETURN NEW;
        END;
      $$;

      CREATE TRIGGER insert_classification_tree_order_a_trigger
      AFTER INSERT ON classification_trees FOR EACH ROW
      EXECUTE FUNCTION update_classification_trees_order_a_trigger ();

      CREATE TRIGGER update_classification_tree_order_a_trigger
      AFTER UPDATE OF parent_classification_alias_id, classification_tree_label_id ON classification_trees FOR EACH ROW
      WHEN ((OLD.parent_classification_alias_id IS DISTINCT FROM NEW.parent_classification_alias_id) OR (OLD.classification_tree_label_id IS DISTINCT FROM NEW.classification_tree_label_id))
      EXECUTE FUNCTION update_classification_trees_order_a_trigger ();

      CREATE
      OR REPLACE FUNCTION update_classification_tree_tree_label_id_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
        BEGIN
        UPDATE classification_trees
        SET
          classification_tree_label_id = NEW.classification_tree_label_id
        WHERE
          classification_trees.classification_alias_id IN (
            SELECT
              classification_alias_paths.id
            FROM
              classification_alias_paths
            WHERE
              classification_alias_paths.ancestor_ids @> ARRAY[NEW.classification_alias_id]::UUID[]
          );
        RETURN NEW;
        END;
      $$;

      CREATE TRIGGER update_classification_tree_tree_label_id_trigger
      AFTER
      UPDATE OF classification_tree_label_id ON classification_trees FOR EACH ROW WHEN (
        OLD.classification_tree_label_id IS DISTINCT
        FROM
          NEW.classification_tree_label_id
      )
      EXECUTE FUNCTION update_classification_tree_tree_label_id_trigger ();
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS update_classification_tree_tree_label_id_trigger ON classification_trees;
      DROP FUNCTION IF EXISTS update_classification_tree_tree_label_id_trigger;

      DROP TRIGGER IF EXISTS insert_classification_tree_order_a_trigger ON classification_trees;
      DROP TRIGGER IF EXISTS update_classification_tree_order_a_trigger ON classification_trees;
      DROP FUNCTION IF EXISTS update_classification_trees_order_a_trigger;

      DROP TRIGGER IF EXISTS update_classification_aliases_order_a_trigger ON classification_aliases;
      DROP FUNCTION IF EXISTS update_classification_aliases_order_a_trigger;

      DROP FUNCTION IF EXISTS update_classification_aliases_order_a;

      ALTER TABLE classification_aliases DROP COLUMN order_a;
      ALTER TABLE classification_aliases ALTER COLUMN created_at DROP DEFAULT;
      ALTER TABLE classification_aliases ALTER COLUMN updated_at DROP DEFAULT;
      DROP INDEX IF EXISTS classification_aliases_order_a_idx;
    SQL
  end
end
