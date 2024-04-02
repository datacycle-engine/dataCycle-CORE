# frozen_string_literal: true

class MigrateTransitivePathFunctionToConcepts < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON classification_groups;
      DROP TRIGGER IF EXISTS update_deleted_at_ccc_relations_transitive_trigger ON classification_groups;
      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_trees;
      DROP TRIGGER IF EXISTS update_ca_paths_transitive_trigger ON classification_aliases;
      DROP TRIGGER IF EXISTS update_ca_paths_transitive_trigger ON classification_trees;
      DROP TRIGGER IF EXISTS update_ca_paths_transitive_trigger ON classification_tree_labels;
      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON classification_groups;
      DROP TRIGGER IF EXISTS update_ccc_relations_transitive_trigger ON classification_groups;
      DROP FUNCTION IF EXISTS delete_ca_paths_transitive_trigger_1;
      DROP FUNCTION IF EXISTS delete_ca_paths_transitive_trigger_2;
      DROP FUNCTION IF EXISTS generate_ca_paths_transitive_statement_trigger_3;
      DROP FUNCTION IF EXISTS generate_ca_paths_transitive_trigger_1;
      DROP FUNCTION IF EXISTS generate_ca_paths_transitive_trigger_2;
      DROP FUNCTION IF EXISTS generate_ca_paths_transitive_trigger_3;
      DROP FUNCTION IF EXISTS generate_ca_paths_transitive_trigger_4;
      DROP FUNCTION IF EXISTS update_ca_paths_transitive_trigger_4;

      DROP FUNCTION IF EXISTS generate_ca_paths_transitive;

      CREATE OR REPLACE FUNCTION upsert_ca_paths_transitive (concept_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths(
          id,
          parent_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types,
          tree_label_id
        ) AS (
          SELECT c.id,
            cl.parent_id,
            ARRAY []::uuid [],
            ARRAY [c.id],
            ARRAY [c.internal_name],
            ARRAY [cl.link_type]::varchar [],
            c.concept_scheme_id
          FROM concepts c
            JOIN concept_links cl ON cl.child_id = c.id
          WHERE c.id = ANY(concept_ids)
          UNION ALL
          SELECT paths.id,
            cl.parent_id,
            ancestor_ids || c.id,
            full_path_ids || c.id,
            full_path_names || c.internal_name,
            CASE
              WHEN cl.parent_id IS NULL THEN paths.link_types
              ELSE paths.link_types || cl.link_type
            END,
            c.concept_scheme_id
          FROM concepts c
            JOIN paths ON paths.parent_id = c.id
            JOIN concept_links cl ON cl.child_id = c.id
          WHERE c.id <> ALL (paths.full_path_ids)
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
            paths.full_path_names || cs.name AS full_path_names,
            paths.link_types AS link_types
          FROM paths
            JOIN concept_schemes cs ON cs.id = paths.tree_label_id
          WHERE paths.parent_id IS NULL
          UNION ALL
          SELECT c.id AS id,
            (cl.parent_id || p1.ancestor_ids) AS ancestors_ids,
            (c.id || p1.full_path_ids) AS full_path_ids,
            (
              c.internal_name || p1.full_path_names
            ) AS full_path_names,
            (cl.link_type || p1.link_types) AS link_types
          FROM concepts c
            JOIN concept_links cl ON cl.child_id = c.id
            JOIN child_paths p1 ON p1.id = cl.parent_id
          WHERE c.id <> ALL (p1.full_path_ids)
        ),
        deleted_capt AS (
          DELETE FROM classification_alias_paths_transitive
          WHERE classification_alias_paths_transitive.id IN (
              SELECT capt.id
              FROM classification_alias_paths_transitive capt
              WHERE capt.full_path_ids && concept_ids
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
        array_remove(child_paths.link_types, NULL)
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names;

      END IF;

      END;

      $$;

      CREATE FUNCTION concept_schemes_update_transitive_paths_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concepts.id))
      FROM (
          SELECT DISTINCT concepts.id
          FROM old_concept_schemes
            JOIN new_concept_schemes ON old_concept_schemes.id = new_concept_schemes.id
            JOIN concepts ON concepts.concept_scheme_id = new_concept_schemes.id
          WHERE old_concept_schemes.name IS DISTINCT
          FROM new_concept_schemes.name
        ) "updated_concepts";

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER concept_schemes_update_transitive_paths_trigger
      AFTER
      UPDATE ON concept_schemes REFERENCING OLD TABLE AS old_concept_schemes NEW TABLE AS new_concept_schemes FOR EACH STATEMENT EXECUTE FUNCTION concept_schemes_update_transitive_paths_trigger_function();

      CREATE FUNCTION concepts_create_transitive_paths_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(new_concepts.id))
      FROM new_concepts;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER concepts_create_transitive_paths_trigger
      AFTER
      INSERT ON concepts REFERENCING NEW TABLE AS new_concepts FOR EACH STATEMENT EXECUTE FUNCTION concepts_create_transitive_paths_trigger_function();

      CREATE FUNCTION concepts_update_transitive_paths_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concepts.id))
      FROM (
          SELECT DISTINCT new_concepts.id
          FROM old_concepts
            JOIN new_concepts ON old_concepts.id = new_concepts.id
          WHERE old_concepts.internal_name IS DISTINCT
          FROM new_concepts.internal_name
            OR old_concepts.concept_scheme_id IS DISTINCT
          FROM new_concepts.concept_scheme_id
        ) "updated_concepts";

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER concepts_update_transitive_paths_trigger
      AFTER
      UPDATE ON concepts REFERENCING OLD TABLE AS old_concepts NEW TABLE AS new_concepts FOR EACH STATEMENT EXECUTE FUNCTION concepts_update_transitive_paths_trigger_function();

      CREATE FUNCTION concepts_delete_transitive_paths_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(old_concepts.id))
      FROM old_concepts;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER concepts_delete_transitive_paths_trigger
      AFTER DELETE ON concepts REFERENCING OLD TABLE AS old_concepts FOR EACH STATEMENT EXECUTE FUNCTION concepts_delete_transitive_paths_trigger_function();

      CREATE FUNCTION concept_links_create_transitive_paths_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(new_concept_links.child_id))
      FROM new_concept_links;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER concept_links_create_transitive_paths_trigger
      AFTER
      INSERT ON concept_links REFERENCING NEW TABLE AS new_concept_links FOR EACH STATEMENT EXECUTE FUNCTION concept_links_create_transitive_paths_trigger_function();

      CREATE FUNCTION concept_links_update_transitive_paths_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concept_links.child_id))
      FROM (
          SELECT DISTINCT new_concept_links.child_id
          FROM old_concept_links
            JOIN new_concept_links ON old_concept_links.id = new_concept_links.id
          WHERE old_concept_links.child_id IS DISTINCT
          FROM new_concept_links.child_id
            OR old_concept_links.parent_id IS DISTINCT
          FROM new_concept_links.parent_id
            OR old_concept_links.link_type IS DISTINCT
          FROM new_concept_links.link_type
        ) "updated_concept_links";

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER concept_links_update_transitive_paths_trigger
      AFTER
      UPDATE ON concept_links REFERENCING OLD TABLE AS old_concept_links NEW TABLE AS new_concept_links FOR EACH STATEMENT EXECUTE FUNCTION concept_links_update_transitive_paths_trigger_function();

      CREATE FUNCTION concept_links_delete_transitive_paths_trigger_function() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(old_concept_links.child_id))
      FROM old_concept_links;

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER concept_links_delete_transitive_paths_trigger
      AFTER DELETE ON concept_links REFERENCING OLD TABLE AS old_concept_links FOR EACH STATEMENT EXECUTE FUNCTION concept_links_delete_transitive_paths_trigger_function();

      ALTER TABLE concept_schemes DISABLE TRIGGER concept_schemes_update_transitive_paths_trigger;
      ALTER TABLE concepts DISABLE TRIGGER concepts_create_transitive_paths_trigger;
      ALTER TABLE concepts DISABLE TRIGGER concepts_update_transitive_paths_trigger;
      ALTER TABLE concepts DISABLE TRIGGER concepts_delete_transitive_paths_trigger;
      ALTER TABLE concept_links DISABLE TRIGGER concept_links_create_transitive_paths_trigger;
      ALTER TABLE concept_links DISABLE TRIGGER concept_links_update_transitive_paths_trigger;
      ALTER TABLE concept_links DISABLE TRIGGER concept_links_delete_transitive_paths_trigger;
    SQL
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER IF EXISTS concept_schemes_update_transitive_paths_trigger ON concept_schemes;
      DROP TRIGGER IF EXISTS concepts_create_transitive_paths_trigger ON concepts;
      DROP TRIGGER IF EXISTS concepts_update_transitive_paths_trigger ON concepts;
      DROP TRIGGER IF EXISTS concepts_delete_transitive_paths_trigger ON concepts;
      DROP TRIGGER IF EXISTS concept_links_create_transitive_paths_trigger ON concept_links;
      DROP TRIGGER IF EXISTS concept_links_update_transitive_paths_trigger ON concept_links;
      DROP TRIGGER IF EXISTS concept_links_delete_transitive_paths_trigger ON concept_links;
      DROP FUNCTION IF EXISTS concept_schemes_update_transitive_paths_trigger_function;
      DROP FUNCTION IF EXISTS concepts_create_transitive_paths_trigger_function;
      DROP FUNCTION IF EXISTS concepts_update_transitive_paths_trigger_function;
      DROP FUNCTION IF EXISTS concepts_delete_transitive_paths_trigger_function;
      DROP FUNCTION IF EXISTS concept_links_create_transitive_paths_trigger_function;
      DROP FUNCTION IF EXISTS concept_links_update_transitive_paths_trigger_function;
      DROP FUNCTION IF EXISTS concept_links_delete_transitive_paths_trigger_function;

      DROP FUNCTION IF EXISTS upsert_ca_paths_transitive;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN IF array_length(classification_alias_ids, 1) > 0 THEN WITH RECURSIVE paths(
          id,
          parent_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types,
          tree_label_id
        ) AS (
          SELECT ca.id,
            cal.parent_classification_alias_id,
            ARRAY []::uuid [],
            ARRAY [ca.id],
            ARRAY [ca.internal_name],
            ARRAY []::text [],
            ct.classification_tree_label_id
          FROM classification_alias_links cal
            JOIN classification_aliases ca ON ca.id = cal.child_classification_alias_id
            AND ca.deleted_at IS NULL
            JOIN classification_trees ct ON ct.classification_alias_id = ca.id
            AND ct.deleted_at IS NULL
          WHERE cal.child_classification_alias_id = ANY(classification_alias_ids)
          UNION ALL
          SELECT paths.id,
            cal.parent_classification_alias_id,
            ancestor_ids || ca.id,
            full_path_ids || ca.id,
            full_path_names || ca.internal_name,
            ARRAY [cal.link_type]::text [] || paths.link_types,
            ct.classification_tree_label_id
          FROM classification_alias_links cal
            JOIN paths ON paths.parent_id = cal.child_classification_alias_id
            JOIN classification_aliases ca ON ca.id = cal.child_classification_alias_id
            AND ca.deleted_at IS NULL
            JOIN classification_trees ct ON ct.classification_alias_id = ca.id
            AND ct.deleted_at IS NULL
          WHERE ca.id <> ALL (paths.full_path_ids)
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

      CREATE FUNCTION delete_ca_paths_transitive_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
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

      CREATE TRIGGER delete_ccc_relations_transitive_trigger
      AFTER DELETE ON classification_groups REFERENCING OLD TABLE AS old_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1();

      CREATE FUNCTION delete_ca_paths_transitive_trigger_2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
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

      CREATE TRIGGER update_deleted_at_ccc_relations_transitive_trigger
      AFTER
      UPDATE ON classification_groups REFERENCING OLD TABLE AS old_classification_groups NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION delete_ca_paths_transitive_trigger_2();

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

      CREATE TRIGGER generate_ca_paths_transitive_trigger
      AFTER
      INSERT ON classification_trees REFERENCING NEW TABLE AS new_classification_trees FOR EACH STATEMENT EXECUTE FUNCTION generate_ca_paths_transitive_statement_trigger_3();

      CREATE FUNCTION generate_ca_paths_transitive_trigger_1() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY [NEW.id]::uuid []);

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER update_ca_paths_transitive_trigger
      AFTER
      UPDATE OF internal_name ON classification_aliases FOR EACH ROW
        WHEN (
          (
            (old.internal_name)::text IS DISTINCT
            FROM (new.internal_name)::text
          )
        ) EXECUTE FUNCTION generate_ca_paths_transitive_trigger_1();

      CREATE FUNCTION generate_ca_paths_transitive_trigger_2() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY [NEW.classification_alias_id]::uuid []);

      RETURN NULL;

      END;

      $$;

      CREATE TRIGGER update_ca_paths_transitive_trigger
      AFTER
      UPDATE OF parent_classification_alias_id,
        classification_alias_id,
        classification_tree_label_id ON classification_trees FOR EACH ROW
        WHEN (
          (
            (
              old.parent_classification_alias_id IS DISTINCT
              FROM new.parent_classification_alias_id
            )
            OR (
              old.classification_alias_id IS DISTINCT
              FROM new.classification_alias_id
            )
            OR (
              new.classification_tree_label_id IS DISTINCT
              FROM old.classification_tree_label_id
            )
          )
        ) EXECUTE FUNCTION generate_ca_paths_transitive_trigger_2();

      CREATE FUNCTION generate_ca_paths_transitive_trigger_3() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (ARRAY_AGG(classification_alias_id))
      FROM (
          SELECT classification_trees.classification_alias_id
          FROM classification_trees
          WHERE classification_trees.classification_tree_label_id = NEW.id
        ) "classification_trees_alias";

      RETURN NEW;

      END;

      $$;

      CREATE TRIGGER update_ca_paths_transitive_trigger
      AFTER
      UPDATE OF name ON classification_tree_labels FOR EACH ROW
        WHEN (
          (
            (old.name)::text IS DISTINCT
            FROM (new.name)::text
          )
        ) EXECUTE FUNCTION generate_ca_paths_transitive_trigger_3();

      CREATE FUNCTION generate_ca_paths_transitive_trigger_4() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
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

      CREATE TRIGGER generate_ccc_relations_transitive_trigger
      AFTER
      INSERT ON classification_groups REFERENCING NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION generate_ca_paths_transitive_trigger_4();

      CREATE FUNCTION update_ca_paths_transitive_trigger_4() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN PERFORM generate_ca_paths_transitive (
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

      CREATE TRIGGER update_ccc_relations_transitive_trigger
      AFTER
      UPDATE ON classification_groups REFERENCING OLD TABLE AS old_classification_groups NEW TABLE AS new_classification_groups FOR EACH STATEMENT EXECUTE FUNCTION update_ca_paths_transitive_trigger_4();
    SQL
  end
end
