# frozen_string_literal: true

class ReplaceViewForClassificationAliasPathsWithTableAndTriggers < ActiveRecord::Migration[5.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL.squish
      DROP VIEW classification_alias_statistics;

      DROP VIEW IF EXISTS classification_alias_paths;

      CREATE TABLE classification_alias_paths (
        id UUID PRIMARY KEY NOT NULL,
        ancestor_ids UUID[],
        full_path_ids UUID[],
        full_path_names VARCHAR[]
      );

      CREATE OR REPLACE FUNCTION generate_classification_alias_paths(classification_alias_ids UUID[]) RETURNS UUID[] LANGUAGE PLPGSQL AS $$
      DECLARE
      	classification_alias_path_ids UUID[];
      BEGIN
        DELETE FROM classification_alias_paths WHERE id || '{}'::UUID[] <@ classification_alias_ids;

        WITH RECURSIVE paths(id, ancestor_ids, full_path_ids, full_path_names) AS (
          SELECT
            classification_aliases.id,
            ARRAY[]::uuid[] AS ancestor_ids,
            ARRAY[classification_aliases.id] AS full_path_ids,
            ARRAY[classification_aliases.internal_name, classification_tree_labels.name] AS full_path_names
          FROM classification_trees
          JOIN classification_aliases ON classification_aliases.id = classification_alias_id
          JOIN classification_tree_labels ON classification_tree_labels.id = classification_tree_label_id
          WHERE parent_classification_alias_id IS NULL
        UNION ALL
          SELECT
            classification_aliases.id,
            paths.id || ancestor_ids AS ancestor_ids,
            classification_aliases.id || full_path_ids AS full_path_ids,
            classification_aliases.internal_name || full_path_names AS full_path_names
          FROM classification_trees
          JOIN paths ON paths.id = classification_trees.parent_classification_alias_id
          JOIN classification_aliases ON classification_aliases.id = classification_alias_id
        ) INSERT INTO classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names)
        SELECT * FROM paths
        WHERE paths.id || '{}'::UUID[] <@ classification_alias_ids;

        SELECT ARRAY_AGG(id) INTO classification_alias_path_ids
      	FROM classification_alias_paths WHERE id || '{}'::UUID[] <@ classification_alias_ids;

        RETURN classification_alias_path_ids;
      END;$$;

      CREATE OR REPLACE FUNCTION generate_classification_alias_paths_trigger_1() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
      	PERFORM generate_classification_alias_paths(NEW.id || '{}'::UUID[]);

      	RETURN NEW;
      END;$$;

      CREATE TRIGGER generate_classification_alias_paths_trigger AFTER INSERT OR UPDATE ON classification_aliases FOR EACH ROW EXECUTE FUNCTION generate_classification_alias_paths_trigger_1();


      CREATE OR REPLACE FUNCTION generate_classification_alias_paths_trigger_2() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      BEGIN
      	PERFORM generate_classification_alias_paths(NEW.parent_classification_alias_id || (NEW.classification_alias_id || '{}'::UUID[]));

      	RETURN NEW;
      END;$$;

      CREATE TRIGGER generate_classification_alias_paths_trigger AFTER INSERT OR UPDATE ON classification_trees FOR EACH ROW EXECUTE FUNCTION generate_classification_alias_paths_trigger_2();


      CREATE OR REPLACE FUNCTION generate_classification_alias_paths_trigger_3() RETURNS TRIGGER LANGUAGE PLPGSQL AS $$
      DECLARE
      	classification_alias_ids UUID[];
      BEGIN
      	SELECT ARRAY_AGG(classification_trees.classification_alias_id) INTO classification_alias_ids
    		FROM classification_trees
    		WHERE classification_trees.classification_tree_label_id = NEW.id;

        PERFORM generate_classification_alias_paths(classification_alias_ids);

      	RETURN NEW;
      END;$$;

      CREATE TRIGGER generate_classification_alias_paths_trigger AFTER INSERT OR UPDATE ON classification_tree_labels FOR EACH ROW EXECUTE FUNCTION generate_classification_alias_paths_trigger_3();


      SELECT generate_classification_alias_paths(ARRAY_AGG(id)) FROM classification_aliases;
    SQL

    recreate_classification_alias_statistics
  end

  def down
    execute <<-SQL.squish
      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_tree_labels;
      DROP FUNCTION generate_classification_alias_paths_trigger_3;

      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_trees;
      DROP FUNCTION generate_classification_alias_paths_trigger_2;

      DROP TRIGGER generate_classification_alias_paths_trigger ON classification_aliases;
      DROP FUNCTION generate_classification_alias_paths_trigger_1;

      DROP FUNCTION IF EXISTS generate_classification_alias_paths;

      DROP VIEW classification_alias_statistics;

      DROP TABLE classification_alias_paths;

      CREATE RECURSIVE VIEW classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names) AS (
        SELECT
          classification_aliases.id,
          ARRAY[]::uuid[] AS ancestor_ids,
          ARRAY[classification_aliases.id] AS full_path_ids,
          ARRAY[classification_aliases.internal_name, classification_tree_labels.name] AS full_path_names
        FROM classification_trees
        JOIN classification_aliases ON classification_aliases.id = classification_alias_id
        JOIN classification_tree_labels ON classification_tree_labels.id = classification_tree_label_id
        WHERE parent_classification_alias_id IS NULL
      UNION ALL
        SELECT
          classification_aliases.id,
          classification_alias_paths.id || ancestor_ids AS ancestor_ids,
          classification_aliases.id || full_path_ids AS full_path_ids,
          classification_aliases.internal_name || full_path_names AS full_path_names
        FROM classification_trees
        JOIN classification_alias_paths ON classification_alias_paths.id = classification_trees.parent_classification_alias_id
        JOIN classification_aliases ON classification_aliases.id = classification_alias_id
      );
    SQL

    recreate_classification_alias_statistics
  end

  def recreate_classification_alias_statistics
    execute <<-SQL
      CREATE VIEW classification_alias_statistics AS (
        WITH descendant_counts AS (
          SELECT
            classification_aliases.id,
            COUNT(CASE WHEN ancestor_id IS NOT NULL THEN 1 END) descendant_count
          FROM classification_aliases
            JOIN (SELECT UNNEST(ancestor_ids) ancestor_id FROM classification_alias_paths) AS exploded_classification_ancestors ON ancestor_id = classification_aliases.id
          GROUP BY classification_aliases.id
        ), linked_content_counts AS (
          SELECT
            classification_aliases.id,
            COUNT(CASE WHEN classification_aliases.id IS NOT NULL THEN 1 END) linked_content_count
          FROM classification_aliases
            JOIN classification_alias_paths ON classification_aliases.id = classification_alias_paths.id
            JOIN classification_groups ON classification_aliases.id = classification_groups.classification_alias_id
            JOIN classification_contents ON classification_groups.classification_id = classification_contents.classification_id
          GROUP BY classification_aliases.id
        ), descendants_linked_content_counts AS (
          SELECT
            ancestor_id id,
            COUNT(*) linked_content_count
          FROM (
                SELECT UNNEST(ancestor_ids) ancestor_id, id classification_alias_id
                FROM classification_alias_paths
              ) AS exploded_classification_ancestors
            JOIN classification_groups ON exploded_classification_ancestors.classification_alias_id = classification_groups.classification_alias_id
            JOIN classification_contents ON classification_groups.classification_id = classification_contents.classification_id
          GROUP BY ancestor_id
        ) SELECT
          classification_aliases.id,
          COALESCE(descendant_count, 0) descendant_count,
          COALESCE(linked_content_counts.linked_content_count, 0) + COALESCE(descendants_linked_content_counts.linked_content_count, 0) linked_content_count
        FROM classification_aliases
          LEFT JOIN descendant_counts ON descendant_counts.id = classification_aliases.id
          LEFT JOIN linked_content_counts ON linked_content_counts.id = classification_aliases.id
          LEFT JOIN descendants_linked_content_counts ON descendants_linked_content_counts.id = classification_aliases.id
      );
    SQL
  end
end
