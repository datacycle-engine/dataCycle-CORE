# frozen_string_literal: true

class RefactorClassificationAliasOrderATrigger < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION update_classification_aliases_order_a (tree_label_ids UUID []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(tree_label_ids, 1) > 0 THEN
      UPDATE classification_aliases
      SET order_a = w.order_a
      FROM (
          WITH RECURSIVE paths (id, updated_at, full_order_a, tree_label_id) AS (
            SELECT classification_aliases.id,
              classification_aliases.updated_at,
              ARRAY [
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
            FROM classification_trees
              JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
              AND classification_aliases.deleted_at IS NULL
            WHERE classification_trees.parent_classification_alias_id IS NULL
              AND classification_trees.deleted_at IS NULL
              AND classification_trees.classification_tree_label_id = ANY (tree_label_ids)
            UNION
            SELECT classification_trees.classification_alias_id,
              classification_aliases.updated_at,
              paths.full_order_a || (
                ROW_NUMBER() OVER (
                  PARTITION BY classification_trees.classification_tree_label_id
                  ORDER BY paths.full_order_a || classification_aliases.order_a::BIGINT ASC,
                    classification_aliases.updated_at ASC
                )
              ),
              classification_trees.classification_tree_label_id
            FROM classification_trees
              JOIN paths ON paths.id = classification_trees.parent_classification_alias_id
              JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
              AND classification_aliases.deleted_at IS NULL
            WHERE classification_trees.deleted_at IS NULL
          )
          SELECT paths.id,
            (
              ROW_NUMBER() OVER (
                PARTITION BY classification_tree_labels.id
                ORDER BY paths.full_order_a ASC,
                  paths.updated_at ASC
              )
            ) AS order_a
          FROM paths
            JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
        ) w
      WHERE w.id = classification_aliases.id
      AND classification_aliases.order_a IS DISTINCT FROM w.order_a;

      END IF;

      END;

      $$;

      DROP TRIGGER IF EXISTS update_classification_aliases_order_a_trigger ON classification_aliases;

      CREATE TRIGGER update_classification_aliases_order_a_trigger
      AFTER
      UPDATE ON classification_aliases REFERENCING NEW TABLE AS updated_classification_aliases OLD TABLE AS old_classification_aliases FOR EACH statement EXECUTE FUNCTION update_classification_aliases_order_a_trigger ();

      CREATE OR REPLACE FUNCTION update_classification_aliases_order_a_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
      FROM (
          SELECT DISTINCT classification_trees.classification_tree_label_id
          FROM classification_trees
          WHERE classification_trees.classification_alias_id IN (
              SELECT updated_classification_aliases.id
              FROM updated_classification_aliases
                INNER JOIN old_classification_aliases ON old_classification_aliases.id = updated_classification_aliases.id
              WHERE old_classification_aliases.order_a IS DISTINCT
              FROM updated_classification_aliases.order_a
                AND updated_classification_aliases.order_a IS NOT NULL
            )
        ) "updated_classification_aliases_alias";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION reset_classification_aliases_order_a (classification_alias_ids UUID []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(classification_alias_ids, 1) > 0 THEN
      UPDATE classification_aliases
      SET order_a = NULL
      WHERE classification_aliases.order_a IS NOT NULL
        AND classification_aliases.id = ANY(classification_alias_ids);

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION insert_classification_trees_order_a_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN
      PERFORM reset_classification_aliases_order_a(ARRAY_AGG(classification_alias_id))
      FROM (
        SELECT new_classification_trees.classification_alias_id
        FROM new_classification_trees
      ) "reset_classification_trees_alias";

      PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
      FROM (
        SELECT DISTINCT new_classification_trees.classification_tree_label_id
        FROM new_classification_trees
      ) "new_classification_trees_alias";

      RETURN NULL;

      END;

      $$;

      DROP TRIGGER IF EXISTS insert_classification_tree_order_a_trigger ON classification_trees;

      CREATE TRIGGER insert_classification_tree_order_a_trigger
      AFTER
      INSERT ON classification_trees REFERENCING NEW TABLE AS new_classification_trees FOR EACH statement EXECUTE FUNCTION insert_classification_trees_order_a_trigger ();

      DROP TRIGGER IF EXISTS update_classification_tree_order_a_trigger ON classification_trees;

      CREATE TRIGGER update_classification_tree_order_a_trigger
      AFTER
      UPDATE ON classification_trees REFERENCING NEW TABLE AS new_classification_trees OLD TABLE AS old_classification_trees FOR EACH statement EXECUTE FUNCTION update_classification_trees_order_a_trigger ();

      CREATE OR REPLACE FUNCTION update_classification_trees_order_a_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN
      PERFORM reset_classification_aliases_order_a(ARRAY_AGG(classification_alias_id))
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

      PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
      FROM (
          SELECT DISTINCT new_classification_trees.classification_tree_label_id
          FROM new_classification_trees
            INNER JOIN old_classification_trees ON old_classification_trees.id = new_classification_trees.id
            INNER JOIN classification_aliases ON classification_aliases.id = new_classification_trees.id
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

      DROP TRIGGER IF EXISTS update_classification_tree_tree_label_id_trigger ON classification_trees;

      CREATE TRIGGER update_classification_tree_tree_label_id_trigger
      AFTER
      UPDATE ON classification_trees REFERENCING NEW TABLE AS new_classification_trees OLD TABLE AS old_classification_trees FOR EACH statement EXECUTE FUNCTION update_classification_tree_tree_label_id_trigger ();

      CREATE OR REPLACE FUNCTION update_classification_tree_tree_label_id (classification_tree_ids UUID []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(classification_tree_ids, 1) > 0 THEN
      UPDATE classification_trees
      SET classification_tree_label_id = updated_classification_trees.classification_tree_label_id
      FROM (
          SELECT new_classification_trees.id,
            classification_trees.classification_tree_label_id
          FROM classification_trees
            INNER JOIN classification_alias_paths ON classification_alias_paths.ancestor_ids @> ARRAY [classification_trees.classification_alias_id]::UUID []
            INNER JOIN classification_trees new_classification_trees ON classification_alias_paths.id = new_classification_trees.classification_alias_id
          WHERE classification_trees.deleted_at IS NULL
            AND classification_trees.id = ANY(classification_tree_ids)
        ) updated_classification_trees
      WHERE updated_classification_trees.id = classification_trees.id;

      END IF;

      END;

      $$;

      CREATE OR REPLACE FUNCTION update_classification_tree_tree_label_id_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN PERFORM update_classification_tree_tree_label_id (ARRAY_AGG(id))
      FROM (
          SELECT new_classification_trees.id
          FROM new_classification_trees
            INNER JOIN old_classification_trees ON old_classification_trees.id = new_classification_trees.id
          WHERE new_classification_trees.deleted_at IS NULL
            AND new_classification_trees.classification_tree_label_id IS DISTINCT
          FROM old_classification_trees.classification_tree_label_id
        ) updated_classification_trees;

      RETURN NULL;

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
      CREATE OR REPLACE FUNCTION update_classification_aliases_order_a (tree_label_ids UUID []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN
      UPDATE classification_aliases
      SET order_a = w.order_a
      FROM (
          WITH RECURSIVE paths (id, updated_at, full_order_a, tree_label_id) AS (
            SELECT classification_aliases.id,
              classification_aliases.updated_at,
              ARRAY [
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
            FROM classification_trees
              JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
              AND classification_aliases.deleted_at IS NULL
            WHERE classification_trees.parent_classification_alias_id IS NULL
              AND classification_trees.deleted_at IS NULL
              AND classification_trees.classification_tree_label_id = ANY (tree_label_ids)
            UNION
            SELECT classification_trees.classification_alias_id,
              classification_aliases.updated_at,
              paths.full_order_a || (
                ROW_NUMBER() OVER (
                  PARTITION BY classification_trees.classification_tree_label_id
                  ORDER BY paths.full_order_a || classification_aliases.order_a::BIGINT ASC,
                    classification_aliases.updated_at ASC
                )
              ),
              classification_trees.classification_tree_label_id
            FROM classification_trees
              JOIN paths ON paths.id = classification_trees.parent_classification_alias_id
              JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
              AND classification_aliases.deleted_at IS NULL
            WHERE classification_trees.deleted_at IS NULL
          )
          SELECT paths.id,
            (
              ROW_NUMBER() OVER (
                PARTITION BY classification_tree_labels.id
                ORDER BY paths.full_order_a ASC,
                  paths.updated_at ASC
              )
            ) AS order_a
          FROM paths
            JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
        ) w
      WHERE w.id = classification_aliases.id;

      END;

      $$;

      DROP TRIGGER IF EXISTS update_classification_aliases_order_a_trigger ON classification_aliases;

      CREATE TRIGGER update_classification_aliases_order_a_trigger
      AFTER
      UPDATE OF order_a ON classification_aliases FOR EACH ROW
        WHEN (
          (
            OLD.order_a IS DISTINCT
            FROM NEW.order_a
          )
          AND (
            OLD.updated_at IS DISTINCT
            FROM NEW.updated_at
          )
        ) EXECUTE FUNCTION update_classification_aliases_order_a_trigger ();

      CREATE OR REPLACE FUNCTION update_classification_aliases_order_a_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN PERFORM update_classification_aliases_order_a (ARRAY_AGG(classification_tree_label_id))
      FROM (
          SELECT DISTINCT classification_trees.classification_tree_label_id
          FROM classification_trees
          WHERE classification_trees.classification_alias_id = NEW.id
        ) "updated_classification_aliases_alias";

      RETURN NEW;

      END;

      $$;

      DROP TRIGGER IF EXISTS insert_classification_tree_order_a_trigger ON classification_trees;

      CREATE TRIGGER insert_classification_tree_order_a_trigger
      AFTER
      INSERT ON classification_trees FOR EACH ROW EXECUTE FUNCTION update_classification_trees_order_a_trigger ();

      DROP TRIGGER IF EXISTS update_classification_tree_order_a_trigger ON classification_trees;

      CREATE TRIGGER update_classification_tree_order_a_trigger
      AFTER
      UPDATE OF parent_classification_alias_id,
        classification_tree_label_id ON classification_trees FOR EACH ROW
        WHEN (
          (
            OLD.parent_classification_alias_id IS DISTINCT
            FROM NEW.parent_classification_alias_id
          )
          OR (
            OLD.classification_tree_label_id IS DISTINCT
            FROM NEW.classification_tree_label_id
          )
        ) EXECUTE FUNCTION update_classification_trees_order_a_trigger ();

      CREATE OR REPLACE FUNCTION update_classification_trees_order_a_trigger () RETURNS TRIGGER LANGUAGE PLPGSQL AS $$ BEGIN
      UPDATE classification_aliases
      SET order_a = NULL
      WHERE classification_aliases.id = NEW.classification_alias_id
        AND classification_aliases.order_a IS NOT NULL;

      PERFORM update_classification_aliases_order_a (
        ARRAY [OLD.classification_tree_label_id, NEW.classification_tree_label_id]::UUID []
      );

      RETURN NEW;

      END;

      $$;

      DROP TRIGGER IF EXISTS update_classification_tree_tree_label_id_trigger ON classification_trees;

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
end
