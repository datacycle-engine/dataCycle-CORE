# frozen_string_literal: true

class FixClassificationAliasLinks < ActiveRecord::Migration[5.2]
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
            additional_classification_groups.classification_alias_id AS parent_classification_alias_id,
            primary_classification_groups.classification_alias_id AS child_classification_alias_id,
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
          link_types
      ) AS (
          SELECT
            ca1.id AS id,
            array_remove(ARRAY[ca2.id]::uuid[], NULL) AS ancestors_ids,
            array_remove(ARRAY[ca1.id, ca2.id]::uuid[], NULL) AS full_path_ids,
            array_remove(ARRAY[ca1.internal_name, ca2.internal_name, classification_tree_labels.name]::varchar[], NULL) AS full_path_names,
            (
              CASE WHEN ca2.id IS NULL THEN
                ARRAY[]::text[]
              ELSE
                ARRAY[classification_alias_links.link_type]::text[]
              END) AS link_types
          FROM
            classification_alias_links
            JOIN classification_aliases ca1 ON ca1.id = classification_alias_links.child_classification_alias_id
            JOIN classification_trees ON classification_trees.classification_alias_id = ca1.id
            JOIN classification_tree_labels ON classification_tree_labels.id = classification_trees.classification_tree_label_id
            LEFT OUTER JOIN classification_aliases ca2 ON ca2.id = classification_alias_links.parent_classification_alias_id
          WHERE
            ca1.id = ANY (classification_alias_ids)
            AND classification_alias_links.link_type = 'broader'
          UNION ALL
          SELECT
            classification_aliases.id AS id,
            (classification_alias_links.parent_classification_alias_id || paths_1.ancestors_ids) AS ancestors_ids,
            (classification_aliases.id || paths_1.full_path_ids) AS full_path_ids,
            (classification_aliases.internal_name || paths_1.full_path_names) AS full_path_names,
            (classification_alias_links.link_type || paths_1.link_types) AS link_types
          FROM
            classification_alias_links
            JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
            JOIN paths paths_1 ON paths_1.id = classification_alias_links.parent_classification_alias_id
          WHERE
            classification_aliases.id <> ALL (paths_1.full_path_ids))
        INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types)
        SELECT DISTINCT
          paths.id,
          paths.ancestors_ids,
          paths.full_path_ids,
          paths.full_path_names,
          paths.link_types
        FROM
          paths
        RETURNING
          classification_alias_id;
        RETURN;
      END;
      $$;

      CREATE OR REPLACE FUNCTION generate_collected_cl_content_relations_transitive (
        content_ids uuid[],
        excluded_classification_ids uuid[]
      )
        RETURNS SETOF uuid
        LANGUAGE PLPGSQL
        AS $$
      BEGIN
        DELETE FROM collected_classification_content_relations
        WHERE content_id = ANY (content_ids);
        RETURN QUERY WITH direct_classification_content_relations AS (
          SELECT DISTINCT
            classification_contents.content_data_id "thing_id",
            classification_groups.classification_alias_id "classification_alias_id"
          FROM
            classification_contents
            JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
              AND classification_groups.deleted_at IS NULL
          WHERE
            classification_contents.content_data_id = ANY (content_ids)
            AND classification_contents.classification_id <> ALL (excluded_classification_ids)
      ),
      full_classification_content_relations AS (
        SELECT DISTINCT
          classification_contents.content_data_id "thing_id",
          classification_alias_paths_transitive.full_path_ids "classification_alias_id"
        FROM
          classification_contents
          JOIN classification_groups ON classification_contents.classification_id = classification_groups.classification_id
            AND classification_groups.deleted_at IS NULL
          JOIN classification_alias_paths_transitive ON classification_groups.classification_alias_id =
            classification_alias_paths_transitive.classification_alias_id
        WHERE
          classification_contents.content_data_id = ANY (content_ids)
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
            ARRAY_AGG(DISTINCT direct_classification_content_relations.classification_alias_id) "direct_content_classification_ids"
          FROM
            direct_classification_content_relations
          GROUP BY
            thing_id) "direct_relations" ON direct_relations.thing_id = things.id
        JOIN (
          SELECT
            t.thing_id,
            ARRAY_AGG(t.classification_alias_id) "full_content_classification_ids"
          FROM ( SELECT DISTINCT
              unnest(full_classification_content_relations.classification_alias_id) AS classification_alias_id,
              full_classification_content_relations.thing_id AS thing_id
            FROM
              full_classification_content_relations) t
          GROUP BY
            t.thing_id) "full_relations" ON full_relations.thing_id = things.id
      RETURNING
        content_id;
        RETURN;
      END;
      $$;
    SQL
  end

  def down
  end
end
