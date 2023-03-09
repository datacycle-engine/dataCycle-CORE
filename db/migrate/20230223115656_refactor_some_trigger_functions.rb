# frozen_string_literal: true

class RefactorSomeTriggerFunctions < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      DROP FUNCTION IF EXISTS generate_ca_paths_transitive;

      CREATE OR REPLACE FUNCTION generate_ca_paths_transitive (classification_alias_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM classification_alias_paths_transitive
      WHERE full_path_ids && classification_alias_ids;

      WITH RECURSIVE paths (
        id,
        ancestors_ids,
        full_path_ids,
        full_path_names,
        link_types
      ) AS (
        SELECT ca1.id AS id,
          array_remove(ARRAY [ca2.id]::uuid [], NULL) AS ancestors_ids,
          array_remove(ARRAY [ca1.id, ca2.id]::uuid [], NULL) AS full_path_ids,
          array_remove(
            ARRAY [ca1.internal_name, ca2.internal_name, classification_tree_labels.name]::varchar [],
            NULL
          ) AS full_path_names,
          (
            CASE
              WHEN ca2.id IS NULL THEN ARRAY []::text []
              ELSE ARRAY [classification_alias_links.link_type]::text []
            END
          ) AS link_types
        FROM classification_alias_links
          JOIN classification_aliases ca1 ON ca1.id = classification_alias_links.child_classification_alias_id
          JOIN classification_trees ON classification_trees.classification_alias_id = ca1.id
          JOIN classification_tree_labels ON classification_tree_labels.id = classification_trees.classification_tree_label_id
          LEFT OUTER JOIN classification_aliases ca2 ON ca2.id = classification_alias_links.parent_classification_alias_id
        WHERE ca1.id = ANY (classification_alias_ids)
          AND classification_alias_links.link_type = 'broader'
        UNION ALL
        SELECT classification_aliases.id AS id,
          (
            classification_alias_links.parent_classification_alias_id || paths_1.ancestors_ids
          ) AS ancestors_ids,
          (
            classification_aliases.id || paths_1.full_path_ids
          ) AS full_path_ids,
          (
            classification_aliases.internal_name || paths_1.full_path_names
          ) AS full_path_names,
          (
            classification_alias_links.link_type || paths_1.link_types
          ) AS link_types
        FROM classification_alias_links
          JOIN classification_aliases ON classification_aliases.id = classification_alias_links.child_classification_alias_id
          JOIN paths paths_1 ON paths_1.id = classification_alias_links.parent_classification_alias_id
        WHERE classification_aliases.id <> ALL (paths_1.full_path_ids)
      )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types
        )
      SELECT DISTINCT paths.id,
        paths.ancestors_ids,
        paths.full_path_ids,
        paths.full_path_names,
        paths.link_types
      FROM paths;

      RETURN;

      END;

      $$;

      DROP FUNCTION IF EXISTS generate_classification_alias_paths;

      CREATE OR REPLACE FUNCTION generate_classification_alias_paths(classification_alias_ids UUID []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM classification_alias_paths
      WHERE id = ANY(classification_alias_ids);

      WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        tree_label_id
      ) AS (
        SELECT classification_aliases.id,
          classification_trees.parent_classification_alias_id,
          ARRAY []::uuid [],
          ARRAY [classification_aliases.id],
          ARRAY [classification_aliases.internal_name],
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
          classification_trees.classification_tree_label_id
        FROM classification_trees
          JOIN paths ON paths.parent_id = classification_trees.classification_alias_id
          JOIN classification_aliases ON classification_aliases.id = classification_trees.classification_alias_id
      )
      INSERT INTO classification_alias_paths(id, ancestor_ids, full_path_ids, full_path_names)
      SELECT paths.id,
        paths.ancestor_ids,
        paths.full_path_ids,
        paths.full_path_names || classification_tree_labels.name
      FROM paths
        JOIN classification_tree_labels ON classification_tree_labels.id = paths.tree_label_id
      WHERE paths.parent_id IS NULL;

      RETURN;

      END;

      $$;

      DROP FUNCTION IF EXISTS generate_content_content_links;

      CREATE OR REPLACE FUNCTION generate_content_content_links(a UUID, b UUID) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      INSERT INTO content_content_links (content_a_id, content_b_id)
      SELECT content_a_id,
        content_b_id
      FROM content_contents
      WHERE content_a_id = a
        AND content_b_id = b ON CONFLICT DO NOTHING;

      INSERT INTO content_content_links (content_a_id, content_b_id)
      SELECT content_b_id,
        content_a_id
      FROM content_contents
      WHERE content_a_id = a
        AND content_b_id = b
        AND relation_b IS NOT NULL ON CONFLICT DO NOTHING;

      RETURN;

      END;

      $$;

      DROP FUNCTION IF EXISTS generate_schedule_occurences;

      CREATE OR REPLACE FUNCTION generate_schedule_occurences (schedule_ids uuid []) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM schedule_occurrences
      WHERE schedule_id = ANY (schedule_ids);

      WITH occurences AS (
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          unnest(
            get_occurrences (
              schedules.rrule::rrule,
              schedules.dtstart AT TIME ZONE 'Europe/Vienna'
            )
          ) AT TIME ZONE 'Europe/Vienna' AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND rrule LIKE '%UNTIL%'
          AND id = ANY (schedule_ids)
        UNION
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          unnest(
            get_occurrences (
              (schedules.rrule || ';UNTIL=2037-12-31')::rrule,
              schedules.dtstart AT TIME ZONE 'Europe/Vienna'
            )
          ) AT TIME ZONE 'Europe/Vienna' AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND rrule NOT LIKE '%UNTIL%'
          AND id = ANY (schedule_ids)
        UNION
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          schedules.dtstart AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND schedules.rrule IS NULL
          AND id = ANY (schedule_ids)
        UNION
        SELECT schedules.id,
          schedules.thing_id,
          CASE
            WHEN duration IS NULL THEN INTERVAL '1 seconds'
            WHEN duration <= INTERVAL '0 seconds' THEN INTERVAL '1 seconds'
            ELSE duration
          END AS duration,
          unnest(schedules.rdate) AS occurence
        FROM schedules
        WHERE schedules.relation IS NOT NULL
          AND id = ANY (schedule_ids)
      )
      INSERT INTO schedule_occurrences (
          schedule_id,
          thing_id,
          duration,
          occurrence
        )
      SELECT occurences.id,
        occurences.thing_id,
        occurences.duration,
        tstzrange(
          occurences.occurence,
          occurences.occurence + occurences.duration
        ) AS occurrence
      FROM occurences
      WHERE occurences.id = ANY (schedule_ids)
        AND NOT EXISTS (
          SELECT 1
          FROM (
              SELECT id "schedule_id",
                UNNEST(exdate) "date"
              FROM schedules
            ) "exdates"
          WHERE exdates.schedule_id = occurences.id
            AND tstzrange(
              DATE_TRUNC('day', exdates.date),
              DATE_TRUNC('day', exdates.date) + INTERVAL '1 day'
            ) && tstzrange(
              occurences.occurence,
              occurences.occurence + occurences.duration
            )
        );

      RETURN;

      END;

      $$;

      DROP FUNCTION IF EXISTS delete_content_content_links;

      CREATE OR REPLACE FUNCTION delete_content_content_links(a UUID, b UUID) RETURNS void LANGUAGE PLPGSQL AS $$ BEGIN
      DELETE FROM content_content_links
      WHERE content_a_id = a
        AND content_b_id = b;

      RETURN;

      END;

      $$;
    SQL
  end
end
