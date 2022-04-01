# frozen_string_literal: true

class CreateTableClassificationAliasPathsTransitive < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<-SQL.squish
      CREATE OR REPLACE VIEW classification_alias_links AS (
        WITH primary_classification_groups AS (
          SELECT DISTINCT
            classification_groups.classification_alias_id,
            first_value(classification_groups.classification_id) OVER (PARTITION BY
        classification_groups.classification_alias_id ORDER BY classification_groups.created_at) AS classification_id
          FROM
            classification_groups
          WHERE
            classification_groups.deleted_at IS NULL
      )
          SELECT
            primary_classification_groups.classification_alias_id AS parent_classification_alias_id,
            additional_classification_groups.classification_alias_id AS child_classification_alias_id,
            'related'::text AS link_type
          FROM (primary_classification_groups
            JOIN classification_groups additional_classification_groups ON primary_classification_groups.classification_id =
        additional_classification_groups.classification_id
              AND additional_classification_groups.classification_alias_id <> primary_classification_groups.classification_alias_id
              AND additional_classification_groups.deleted_at IS NULL)
          UNION
          SELECT
            classification_trees.parent_classification_alias_id,
            classification_trees.classification_alias_id AS child_classification_alias_id,
            'broader'::text AS link_type
          FROM
            classification_trees
        WHERE
          classification_trees.deleted_at IS NULL);

      DROP VIEW IF EXISTS classification_alias_paths_transitive;

      CREATE TABLE classification_alias_paths_transitive (
        id uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
        classification_alias_id uuid NOT NULL,
        ancestor_ids uuid[],
        full_path_ids uuid[],
        full_path_names varchar[],
        link_types varchar[]
      );

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (
        classification_alias_ids uuid[]
      )
        RETURNS SETOF uuid
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM classification_alias_paths_transitive
        WHERE full_path_ids && classification_alias_ids;
        RETURN QUERY WITH RECURSIVE paths (
          id,
          ancestors_ids,
          full_path_ids,
          full_path_names,
          link_types,
          tree_label_name,
          classification_alias_id
      ) AS (
          SELECT
            classification_alias_links.child_classification_alias_id AS id,
            ARRAY[]::uuid[] AS ancestors_ids,
            ARRAY[classification_alias_links.child_classification_alias_id] AS full_path_ids,
            ARRAY[classification_aliases.internal_name] AS full_path_names,
            ARRAY[]::text[] AS link_types,
            classification_tree_labels.name,
            classification_aliases.id
          FROM (((classification_alias_links
                JOIN classification_aliases ON ((classification_aliases.id = classification_alias_links.child_classification_alias_id)))
              JOIN classification_trees ON (((classification_trees.classification_alias_id = classification_aliases.id))))
            JOIN classification_tree_labels ON ((classification_tree_labels.id = classification_trees.classification_tree_label_id)))
        WHERE
          classification_aliases.id = ANY (classification_alias_ids)
        UNION ALL
        SELECT
          classification_alias_links.parent_classification_alias_id AS id,
          (paths_1.ancestors_ids || classification_alias_links.parent_classification_alias_id) AS ancestors_ids,
          (paths_1.full_path_ids || classification_aliases.id) AS full_path_ids,
          (paths_1.full_path_names || classification_aliases.internal_name) AS full_path_names,
          (paths_1.link_types || classification_alias_links.link_type) AS link_types,
          classification_tree_labels.name,
          paths_1.classification_alias_id
        FROM ((classification_alias_links
            JOIN classification_aliases ON ((classification_aliases.id = classification_alias_links.parent_classification_alias_id)))
          JOIN paths paths_1 ON ((paths_1.id = classification_alias_links.child_classification_alias_id))
          JOIN classification_trees ON (((classification_trees.parent_classification_alias_id IS NULL)
                AND (classification_trees.classification_alias_id = classification_aliases.id)))
          JOIN classification_tree_labels ON ((classification_tree_labels.id = classification_trees.classification_tree_label_id)))
        WHERE (classification_alias_links.parent_classification_alias_id <> ALL (paths_1.full_path_ids)))
      INSERT INTO classification_alias_paths_transitive (
        classification_alias_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types)
      SELECT DISTINCT
        paths.classification_alias_id,
        paths.ancestors_ids,
        paths.full_path_ids,
        paths.full_path_names || paths.tree_label_name,
        paths.link_types
      FROM
        paths
      RETURNING
        classification_alias_id;
        RETURN;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive_trigger_1 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_ca_paths_transitive (ARRAY[NEW.id]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive_trigger_2 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_ca_paths_transitive (NEW.parent_classification_alias_id || ARRAY[NEW.classification_alias_id]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive_trigger_3 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_ca_paths_transitive (ARRAY_AGG(classification_alias_id))
        FROM (
          SELECT
            classification_trees.classification_alias_id
          FROM
            classification_trees
          WHERE
            classification_trees.classification_tree_label_id = NEW.id) "classification_trees_alias";
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER generate_ca_paths_transitive_trigger
        AFTER INSERT ON classification_aliases
        FOR EACH ROW
        EXECUTE PROCEDURE generate_ca_paths_transitive_trigger_1 ();

      CREATE TRIGGER update_ca_paths_transitive_trigger
        AFTER UPDATE OF internal_name ON classification_aliases
        FOR EACH ROW
        WHEN (OLD.internal_name IS DISTINCT FROM NEW.internal_name)
        EXECUTE PROCEDURE generate_ca_paths_transitive_trigger_1 ();

      CREATE TRIGGER generate_ca_paths_transitive_trigger
        AFTER INSERT ON classification_trees
        FOR EACH ROW
        EXECUTE FUNCTION generate_ca_paths_transitive_trigger_2 ();

      CREATE TRIGGER update_ca_paths_transitive_trigger
        AFTER UPDATE OF parent_classification_alias_id,
        classification_alias_id,
        classification_tree_label_id ON classification_trees
        FOR EACH ROW
        WHEN (OLD.parent_classification_alias_id IS DISTINCT FROM NEW.parent_classification_alias_id OR
          OLD.classification_alias_id IS DISTINCT FROM NEW.classification_alias_id OR NEW.classification_tree_label_id IS
          DISTINCT FROM OLD.classification_tree_label_id)
        EXECUTE FUNCTION generate_ca_paths_transitive_trigger_2 ();

      CREATE TRIGGER generate_ca_paths_transitive_trigger
        AFTER INSERT ON classification_tree_labels
        FOR EACH ROW
        EXECUTE FUNCTION generate_ca_paths_transitive_trigger_3 ();

      CREATE TRIGGER update_ca_paths_transitive_trigger
        AFTER UPDATE OF name ON classification_tree_labels
        FOR EACH ROW
        WHEN (OLD.name IS DISTINCT FROM NEW.name)
        EXECUTE FUNCTION generate_ca_paths_transitive_trigger_3 ();

      CREATE OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive (
        content_ids uuid[],
        excluded_classification_ids uuid[]
      )
        RETURNS SETOF uuid
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        CREATE TEMP TABLE content_ids_table ON COMMIT DROP AS (
          SELECT
            unnest(content_ids
            ) AS id
          );
        DELETE FROM collected_classification_content_relations
        WHERE content_id IN (
            SELECT
              id
            FROM
              content_ids_table);
        RETURN QUERY WITH direct_classification_content_relations AS (
          SELECT DISTINCT
            things.id "thing_id",
            classification_groups.classification_alias_id "classification_alias_id"
          FROM
            things
            JOIN classification_contents ON things.id = classification_contents.content_data_id
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
          WHERE
            things.id IN (
              SELECT
                id
              FROM
                content_ids_table)
              AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      ),
      full_classification_content_relations AS (
        SELECT DISTINCT
          things.id "thing_id",
          classification_alias_paths_transitive.classification_alias_id
        FROM
          things
          JOIN classification_contents ON things.id = classification_contents.content_data_id
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id = ANY
            (classification_alias_paths_transitive.full_path_ids)
        WHERE
          things.id IN (
            SELECT
              id
            FROM
              content_ids_table)
            AND classification_contents.classification_id <> ALL (excluded_classification_ids))
        INSERT INTO collected_classification_content_relations (
          content_id,
          direct_classification_alias_ids,
          full_classification_alias_ids)
        SELECT
          things.id "content_id",
          direct_content_classification_ids "direct_classification_alias_ids",
          full_content_classification_ids "full_classification_alias_ids"
        FROM
          things
          JOIN (
            SELECT
              thing_id,
              ARRAY_AGG(direct_classification_content_relations.classification_alias_id) "direct_content_classification_ids"
            FROM
              direct_classification_content_relations
            GROUP BY
              thing_id) "direct_relations" ON direct_relations.thing_id = things.id
          JOIN (
            SELECT
              thing_id,
              ARRAY_AGG(full_classification_content_relations.classification_alias_id) "full_content_classification_ids"
            FROM
              full_classification_content_relations
            GROUP BY
              thing_id) "full_relations" ON full_relations.thing_id = things.id
        RETURNING
          content_id;
        DROP TABLE content_ids_table;
        RETURN;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_ccc_relations_transitive_trigger_1 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_collected_cl_content_relations_transitive (ARRAY_AGG(content_data_id), ARRAY[]::uuid[])
        FROM ( SELECT DISTINCT
            classification_contents.content_data_id
          FROM
            new_classification_alias_paths_transitive
            INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY
        (new_classification_alias_paths_transitive.full_path_ids)
              AND classification_groups.deleted_at IS NULL
            INNER JOIN classification_contents ON classification_contents.classification_id =
        classification_groups.classification_id) "collected_classification_content_relations_alias";
        RETURN NULL;
      END;
      $$;

      CREATE OR REPLACE FUNCTION delete_ccc_relations_transitive_trigger_2 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_collected_cl_content_relations_transitive (ARRAY_AGG(content_data_id), ARRAY[]::uuid[])
        FROM ( SELECT DISTINCT
            classification_contents.content_data_id
          FROM
            old_classification_alias_paths_transitive
            INNER JOIN classification_groups ON classification_groups.classification_alias_id = ANY
        (old_classification_alias_paths_transitive.full_path_ids)
              AND classification_groups.deleted_at IS NULL
            INNER JOIN classification_contents ON classification_contents.classification_id =
        classification_groups.classification_id) "collected_classification_content_relations_alias";
        RETURN NULL;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_ccc_relations_transitive_trigger_2 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_collected_cl_content_relations_transitive (ARRAY[NEW.content_data_id]::uuid[], ARRAY[]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION delete_ccc_relations_transitive_trigger_1 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_collected_cl_content_relations_transitive (ARRAY[OLD.content_data_id]::uuid[], ARRAY[OLD.classification_id]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER generate_ccc_relations_transitive_trigger
        AFTER INSERT ON classification_alias_paths_transitive REFERENCING NEW TABLE AS new_classification_alias_paths_transitive
        FOR EACH STATEMENT
        EXECUTE FUNCTION generate_ccc_relations_transitive_trigger_1 ();

      ALTER TABLE classification_alias_paths_transitive DISABLE TRIGGER generate_ccc_relations_transitive_trigger;

      CREATE TRIGGER delete_ccc_relations_transitive_trigger
        AFTER DELETE ON classification_alias_paths_transitive REFERENCING OLD TABLE AS old_classification_alias_paths_transitive
        FOR EACH STATEMENT
        EXECUTE FUNCTION delete_ccc_relations_transitive_trigger_2 ();

      ALTER TABLE classification_alias_paths_transitive DISABLE TRIGGER delete_ccc_relations_transitive_trigger;

      CREATE TRIGGER generate_ccc_relations_transitive_trigger
        AFTER INSERT ON classification_contents
        FOR EACH ROW
        EXECUTE FUNCTION generate_ccc_relations_transitive_trigger_2 ();

      ALTER TABLE classification_contents DISABLE TRIGGER generate_ccc_relations_transitive_trigger;

      CREATE TRIGGER delete_ccc_relations_transitive_trigger
        AFTER DELETE ON classification_contents
        FOR EACH ROW
        EXECUTE FUNCTION delete_ccc_relations_transitive_trigger_1 ();

      ALTER TABLE classification_contents DISABLE TRIGGER delete_ccc_relations_transitive_trigger;

      CREATE TRIGGER update_ccc_relations_transitive_trigger
        AFTER UPDATE OF content_data_id,
        classification_id,
        relation ON classification_contents
        FOR EACH ROW
        WHEN (OLD.content_data_id IS DISTINCT FROM NEW.content_data_id OR OLD.classification_id IS DISTINCT FROM
          NEW.classification_id OR OLD.relation IS DISTINCT FROM NEW.relation)
        EXECUTE FUNCTION generate_ccc_relations_transitive_trigger_2 ();

      ALTER TABLE classification_contents DISABLE TRIGGER update_ccc_relations_transitive_trigger;

      CREATE OR REPLACE FUNCTION delete_ca_paths_transitive_trigger_1 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_ca_paths_transitive (ARRAY[OLD.classification_alias_id]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive_trigger_4 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_ca_paths_transitive (ARRAY[NEW.classification_alias_id]::uuid[]);
        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER delete_ccc_relations_transitive_trigger
        AFTER DELETE ON classification_groups
        FOR EACH ROW
        EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1 ();

      ALTER TABLE classification_groups DISABLE TRIGGER delete_ccc_relations_transitive_trigger;

      CREATE TRIGGER generate_ccc_relations_transitive_trigger
        AFTER INSERT ON classification_groups
        FOR EACH ROW
        EXECUTE FUNCTION generate_ca_paths_transitive_trigger_4 ();

      ALTER TABLE classification_groups DISABLE TRIGGER generate_ccc_relations_transitive_trigger;

      CREATE TRIGGER update_ccc_relations_transitive_trigger
        AFTER UPDATE OF deleted_at ON classification_groups
        FOR EACH ROW
        WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
        EXECUTE FUNCTION delete_ca_paths_transitive_trigger_1 ();

      ALTER TABLE classification_groups DISABLE TRIGGER update_ccc_relations_transitive_trigger;

      CREATE OR REPLACE FUNCTION generate_collected_classification_content_relations_trigger_3 ()
        RETURNS TRIGGER
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        PERFORM
          generate_collected_classification_content_relations (ARRAY_AGG(content_data_id), ARRAY[]::uuid[])
        FROM ( SELECT DISTINCT
            classification_contents.content_data_id
          FROM
            classification_alias_paths
            INNER JOIN classification_groups ON classification_groups.classification_alias_id = classification_alias_paths.id
              AND classification_groups.deleted_at IS NULL
            INNER JOIN classification_contents ON classification_contents.classification_id = classification_groups.classification_id
          WHERE
            classification_alias_paths.full_path_ids && ARRAY[NEW.id]::uuid[]) "relevant_content_ids";
        RETURN NEW;
      END;
      $$;

      CREATE INDEX classification_alias_paths_transitive_full_path_ids ON classification_alias_paths_transitive USING GIN (full_path_ids);

      CREATE INDEX classification_alias_paths_full_path_ids ON classification_alias_paths USING GIN (full_path_ids);

      DROP INDEX IF EXISTS index_classification_contents_on_classification_id;

      CREATE INDEX IF NOT EXISTS index_classification_contents_on_classification_id ON classification_contents (classification_id, content_data_id);
    SQL

    execute('VACUUM classification_alias_paths_transitive;')
    execute('ANALYZE classification_alias_paths_transitive;')
  end

  def down
    execute <<-SQL.squish
      DROP TABLE IF EXISTS classification_alias_paths_transitive;

      CREATE OR REPLACE RECURSIVE VIEW classification_alias_paths_transitive (id, ancestors_ids, full_path_ids,
        full_path_names, link_types)
      AS (
        SELECT
          child_classification_alias_id "id",
          ARRAY[]::uuid[] "ancestors_ids",
          ARRAY[child_classification_alias_id] "full_path_ids",
          ARRAY[internal_name, classification_tree_labels.name] "full_path_names",
          ARRAY[]::text[] "link_types"
        FROM
          classification_alias_links
          JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
          JOIN classification_trees ON classification_trees.parent_classification_alias_id IS NULL
            AND classification_trees.classification_alias_id = classification_aliases.id
          JOIN classification_tree_labels ON classification_tree_labels.id = classification_tree_label_id
        WHERE
          classification_alias_links.parent_classification_alias_id IS NULL
        UNION ALL
        SELECT
          child_classification_alias_id "id",
          classification_alias_links.parent_classification_alias_id || ancestors_ids "ancestors_ids",
          classification_aliases.id || full_path_ids "full_path_ids",
          classification_aliases.internal_name || full_path_names "full_path_names",
          classification_alias_links.link_type || link_types "link_types"
        FROM
          classification_alias_links
          JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
          JOIN classification_alias_paths_transitive ON classification_alias_paths_transitive.id =
            classification_alias_links.parent_classification_alias_id
        WHERE
          child_classification_alias_id != ALL (full_path_ids));

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_aliases;

      DROP TRIGGER IF EXISTS update_ca_paths_transitive_trigger ON classification_aliases;

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_trees;

      DROP TRIGGER IF EXISTS update_ca_paths_transitive_trigger ON classification_trees;

      DROP TRIGGER IF EXISTS generate_ca_paths_transitive_trigger ON classification_tree_labels;

      DROP TRIGGER IF EXISTS update_ca_paths_transitive_trigger ON classification_tree_labels;

      DROP FUNCTION generate_ca_paths_transitive;

      DROP FUNCTION generate_ca_paths_transitive_trigger_1;

      DROP FUNCTION generate_ca_paths_transitive_trigger_2;

      DROP FUNCTION generate_ca_paths_transitive_trigger_3;

      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON classification_alias_paths_transitive;

      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON classification_alias_paths_transitive;

      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON classification_contents;

      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON classification_contents;

      DROP TRIGGER IF EXISTS update_ccc_relations_transitive_trigger ON classification_contents;

      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON classification_groups;

      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON classification_groups;

      DROP TRIGGER IF EXISTS update_ccc_relations_transitive_trigger ON classification_groups;

      DROP FUNCTION delete_ca_paths_transitive_trigger_1;

      DROP FUNCTION generate_ca_paths_transitive_trigger_4;

      DROP FUNCTION generate_collected_cl_content_relations_transitive;

      DROP FUNCTION generate_ccc_relations_transitive_trigger_1;

      DROP FUNCTION delete_ccc_relations_transitive_trigger_2;

      DROP FUNCTION generate_ccc_relations_transitive_trigger_2;

      DROP FUNCTION delete_ccc_relations_transitive_trigger_1;

      DROP INDEX IF EXISTS classification_alias_paths_transitive_full_path_ids;

      DROP INDEX IF EXISTS classification_alias_paths_full_path_ids;

      DROP INDEX IF EXISTS index_classification_contents_on_classification_id;

      CREATE INDEX IF NOT EXISTS index_classification_contents_on_classification_id ON classification_contents (classification_id);
    SQL
  end
end
