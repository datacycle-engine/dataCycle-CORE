# frozen_string_literal: true

class RefactorTriggerForClassificationGroups < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER delete_ccc_relations_transitive_trigger
      AFTER DELETE ON classification_groups REFERENCING OLD TABLE AS old_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1();

      CREATE OR REPLACE FUNCTION delete_ca_paths_transitive_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
          ARRAY_AGG(
            deleted_classification_groups.classification_alias_id
          )
        )
      FROM (
          SELECT DISTINCT old_classification_groups.classification_alias_id
          FROM old_classification_groups
        ) "deleted_classification_groups";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION delete_ca_paths_transitive_trigger_2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
          ARRAY_AGG(
            deleted_classification_groups.classification_alias_id
          )
        )
      FROM (
          SELECT DISTINCT old_classification_groups.classification_alias_id
          FROM old_classification_groups
            INNER JOIN new_classification_groups ON old_classification_groups.id = new_classification_groups.id
          WHERE old_classification_groups.deleted_at IS NULL
            AND new_classification_groups.deleted_at IS NOT NULL
        ) "deleted_classification_groups";

      RETURN NULL;

      END;

      $$;

      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER update_deleted_at_ccc_relations_transitive_trigger
      AFTER
      UPDATE ON classification_groups REFERENCING OLD TABLE AS old_classification_groups NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION delete_ca_paths_transitive_trigger_2();

      DROP TRIGGER IF EXISTS update_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER update_ccc_relations_transitive_trigger
      AFTER
      UPDATE ON classification_groups REFERENCING OLD TABLE AS old_classification_groups NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION update_ca_paths_transitive_trigger_4();

      CREATE OR REPLACE FUNCTION update_ca_paths_transitive_trigger_4() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
          ARRAY_AGG(
            updated_classification_groups.classification_alias_id
          )
        )
      FROM (
          SELECT DISTINCT old_classification_groups.classification_alias_id
          FROM old_classification_groups
            INNER JOIN new_classification_groups ON old_classification_groups.id = new_classification_groups.id
          WHERE old_classification_groups.classification_id IS DISTINCT
          FROM new_classification_groups.classification_id
            OR old_classification_groups.classification_alias_id IS DISTINCT
          FROM new_classification_groups.classification_alias_id
          UNION
          SELECT DISTINCT new_classification_groups.classification_alias_id
          FROM old_classification_groups
            INNER JOIN new_classification_groups ON old_classification_groups.id = new_classification_groups.id
          WHERE old_classification_groups.classification_id IS DISTINCT
          FROM new_classification_groups.classification_id
            OR old_classification_groups.classification_alias_id IS DISTINCT
          FROM new_classification_groups.classification_alias_id
        ) "updated_classification_groups";

      RETURN NULL;

      END;

      $$;

      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER generate_ccc_relations_transitive_trigger
      AFTER
      INSERT ON classification_groups REFERENCING NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION generate_ca_paths_transitive_trigger_4();

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive_trigger_4() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
          ARRAY_AGG(
            DISTINCT inserted_classification_groups.classification_alias_id
          )
        )
      FROM (
          SELECT DISTINCT new_classification_groups.classification_alias_id
          FROM new_classification_groups
        ) "inserted_classification_groups";

      RETURN NULL;

      END;

      $$;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(classification_alias_ids, 1) > 0 THEN WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types,
        tree_label_id
      ) AS (
        SELECT classification_aliases.id,
          classification_trees.parent_classification_alias_id,
          ARRAY []::uuid [],
          ARRAY [classification_aliases.id],
          ARRAY [classification_aliases.internal_name],
          ARRAY []::text [],
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
        WHERE classification_trees.classification_alias_id = ANY(classification_alias_ids)
        UNION ALL
        SELECT paths.id,
          classification_trees.parent_classification_alias_id,
          ancestor_ids || classification_aliases.id,
          full_path_ids || classification_aliases.id,
          full_path_names || classification_aliases.internal_name,
          ARRAY ['broader'] || paths.link_types,
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN paths ON paths.parent_id = classification_trees.classification_alias_id
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
      ),
      child_paths(
        id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types
      ) AS (
        SELECT paths.id AS id,
          paths.ancestor_ids AS ancestor_ids,
          paths.full_path_ids AS full_path_ids,
          paths.full_path_names || classification_tree_labels.name AS full_path_names,
          paths.link_types AS link_types
        FROM paths
          JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT classification_aliases.id AS id,
          (
            classification_alias_links.parent_classification_alias_id || p1.ancestor_ids
          ) AS ancestors_ids,
          (
            classification_aliases.id || p1.full_path_ids
          ) AS full_path_ids,
          (
            classification_aliases.internal_name || p1.full_path_names
          ) AS full_path_names,
          (
            classification_alias_links.link_type || p1.link_types
          ) AS link_types
        FROM classification_alias_links
          JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
          JOIN child_paths p1 ON p1.id = classification_alias_links.parent_classification_alias_id
        WHERE classification_aliases.id <> ALL (p1.full_path_ids)
      ),
      deleted_capt AS (
        DELETE FROM classification_alias_paths_transitive
        WHERE classification_alias_paths_transitive.id IN (
            SELECT capt.id
            FROM classification_alias_paths_transitive capt
            WHERE capt.full_path_ids && classification_alias_ids
              AND NOT EXISTS (
                SELECT 1
                FROM child_paths
                WHERE child_paths.full_path_ids = capt.full_path_ids
              )
            ORDER BY capt.id ASC FOR
            UPDATE SKIP LOCKED
          )
      )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types
        )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        child_paths.link_types
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names;

      END IF;

      END;

      $$;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER delete_ccc_relations_transitive_trigger
      AFTER DELETE ON classification_groups FOR EACH ROW EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1();

      CREATE OR REPLACE FUNCTION delete_ca_paths_transitive_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY [OLD.classification_alias_id]::uuid []);

      RETURN NEW;

      END;

      $$;

      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER update_deleted_at_ccc_relations_transitive_trigger
      AFTER
      UPDATE OF deleted_at ON classification_groups FOR EACH ROW
        WHEN (
          (
            (old.deleted_at IS NULL)
            AND (new.deleted_at IS NOT NULL)
          )
        ) EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1();

      DROP FUNCTION delete_ca_paths_transitive_trigger_2();

      DROP TRIGGER IF EXISTS update_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER update_ccc_relations_transitive_trigger
      AFTER
      UPDATE OF classification_id,
        classification_alias_id ON classification_groups FOR EACH ROW
        WHEN (
          (
            (
              old.classification_id IS DISTINCT
              FROM new.classification_id
            )
            OR (
              old.classification_alias_id IS DISTINCT
              FROM new.classification_alias_id
            )
          )
        ) EXECUTE FUNCTION update_ca_paths_transitive_trigger_4();

      CREATE OR REPLACE FUNCTION update_ca_paths_transitive_trigger_4() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
          ARRAY [OLD.classification_alias_id, NEW.classification_alias_id]::uuid []
        );

      RETURN NEW;

      END;

      $$;

      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON classification_groups;

      CREATE TRIGGER generate_ccc_relations_transitive_trigger
      AFTER
      INSERT ON classification_groups FOR EACH ROW EXECUTE FUNCTION generate_ca_paths_transitive_trigger_4();

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive_trigger_4() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY [NEW.classification_alias_id]::uuid []);

      RETURN NEW;

      END;

      $$;
    SQL
  end
end
