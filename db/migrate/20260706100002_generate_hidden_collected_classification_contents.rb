# frozen_string_literal: true

# Redmine #47172 (M3): make a hidden mapping flow into collected_classification_contents.hidden.
#
# A mapping is hidden when its "related" concept_link has hidden = true. In the transitive
# machinery (live in this installation) relatedness is implicit in the path arrays, so we:
#
#   1. upsert_ca_paths_transitive: carry a per-link `link_hidden` array and store, per path,
#      the SET of concept ids reached *through* a hidden mapping (`hidden_ids`). Alignment-free:
#      the CCC generators only test set membership.
#   2. concept_links_update_transitive_paths_trigger_function: also rebuild paths when `hidden`
#      changes (a toggle keeps the same structure, only `hidden` differs).
#   3. generate_ccc_relations_transitive_update_trigger: the existing regen fires on capt INSERT
#      only; a hidden toggle is an ON CONFLICT UPDATE, so add an UPDATE-path regen scoped to rows
#      whose hidden_ids actually changed.
#   4. the two transitive generators + the non-transitive generator: emit hidden, and let a
#      visible route win the (thing, relation, alias) unique key ("visible wins").
class GenerateHiddenCollectedClassificationContents < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.upsert_ca_paths_transitive(concept_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths(
        id,
        parent_id,
        ancestor_ids,
        full_path_ids,
        full_path_names,
        link_types,
        link_hidden,
        tree_label_id
      ) AS (
        SELECT c.id,
          cl.parent_id,
          ARRAY []::uuid [],
          ARRAY [c.id],
          ARRAY [c.internal_name],
          ARRAY [cl.link_type]::varchar [],
          ARRAY [cl.link_type = 'related' AND cl.hidden]::boolean [],
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
          CASE
            WHEN cl.parent_id IS NULL THEN paths.link_hidden
            ELSE paths.link_hidden || (cl.link_type = 'related' AND cl.hidden)
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
        link_types,
        link_hidden
      ) AS (
        SELECT paths.id,
          paths.ancestor_ids,
          paths.full_path_ids,
          paths.full_path_names || cs.name,
          paths.link_types,
          paths.link_hidden
        FROM paths
          JOIN concept_schemes cs ON cs.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT c.id,
          cl.parent_id || p1.ancestor_ids,
          c.id || p1.full_path_ids,
          c.internal_name || p1.full_path_names,
          cl.link_type || p1.link_types,
          (cl.link_type = 'related' AND cl.hidden) || p1.link_hidden
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
            ORDER BY capt.id ASC FOR UPDATE SKIP LOCKED
          )
      )
      INSERT INTO classification_alias_paths_transitive (
          classification_alias_id,
          ancestor_ids,
          full_path_ids,
          full_path_names,
          link_types,
          hidden_ids
        )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        array_remove(child_paths.link_types, NULL),
        (
          SELECT COALESCE(array_agg(child_paths.full_path_ids [i]), ARRAY []::uuid [])
          FROM generate_subscripts(child_paths.full_path_ids, 1) AS i
          WHERE EXISTS (
              SELECT 1
              FROM generate_subscripts(child_paths.link_hidden, 1) AS j
              WHERE j < i
                AND child_paths.link_hidden [j]
            )
        )
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names,
        hidden_ids = EXCLUDED.hidden_ids
      WHERE classification_alias_paths_transitive.full_path_names IS DISTINCT
      FROM EXCLUDED.full_path_names
        OR classification_alias_paths_transitive.hidden_ids IS DISTINCT
      FROM EXCLUDED.hidden_ids;
      END IF;
      END; $$;

      CREATE OR REPLACE FUNCTION public.concept_links_update_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concept_links.child_id)) FROM ( SELECT DISTINCT new_concept_links.child_id FROM old_concept_links JOIN new_concept_links ON old_concept_links.id = new_concept_links.id WHERE old_concept_links.child_id IS DISTINCT FROM new_concept_links.child_id OR old_concept_links.parent_id IS DISTINCT FROM new_concept_links.parent_id OR old_concept_links.link_type IS DISTINCT FROM new_concept_links.link_type OR old_concept_links.hidden IS DISTINCT FROM new_concept_links.hidden ) "updated_concept_links"; RETURN NULL; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_relations_transitive_update_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM public.generate_ccc_from_ca_ids_transitive (array_agg(cccra.id)) FROM ( SELECT DISTINCT ca.id FROM new_classification_alias_paths_transitive ncapt JOIN old_classification_alias_paths_transitive ocapt ON ocapt.id = ncapt.id JOIN classification_aliases ca ON ca.id = ANY (ncapt.full_path_ids) AND ca.deleted_at IS NULL WHERE ncapt.hidden_ids IS DISTINCT FROM ocapt.hidden_ids ) "cccra"; RETURN NULL; END; $$;

      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_update_trigger ON public.classification_alias_paths_transitive;
      CREATE TRIGGER generate_ccc_relations_transitive_update_trigger AFTER UPDATE ON public.classification_alias_paths_transitive REFERENCING OLD TABLE AS old_classification_alias_paths_transitive NEW TABLE AS new_classification_alias_paths_transitive FOR EACH STATEMENT EXECUTE FUNCTION public.generate_ccc_relations_transitive_update_trigger_function();

      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_contents.relation,
            c2.id
          ) classification_contents.content_data_id "thing_id",
          c2.id "classification_alias_id",
          c2.concept_scheme_id "classification_tree_label_id",
          concepts.id = c2.id "direct",
          c2.id = ANY (classification_alias_paths_transitive.hidden_ids) "hidden",
          classification_contents.relation,
          ROW_NUMBER() over (
            PARTITION by classification_contents.content_data_id,
            classification_alias_paths_transitive.id,
            c2.concept_scheme_id
            ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
          ) AS "row_number"
        FROM classification_contents
          JOIN concepts ON concepts.classification_id = classification_contents.classification_id
          JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id
          JOIN concepts c2 ON c2.id = ANY (
            classification_alias_paths_transitive.full_path_ids
          )
          JOIN classification_alias_paths cap ON cap.id = c2.id
        WHERE cap.full_path_ids && ca_ids
        ORDER BY classification_contents.content_data_id,
          classification_contents.relation,
          c2.id,
          "direct" DESC,
          "hidden" ASC,
          "row_number"
      ),
      new_collected_classification_contents AS (
        SELECT full_classification_content_relations.thing_id,
          full_classification_content_relations.classification_alias_id,
          full_classification_content_relations.classification_tree_label_id,
          CASE
            WHEN full_classification_content_relations.direct THEN 'direct'
            WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
            ELSE 'related'
          END AS "link_type",
          full_classification_content_relations.hidden,
          full_classification_content_relations.relation
        FROM full_classification_content_relations
        WHERE full_classification_content_relations.classification_alias_id = ANY(ca_ids)
      ),
      deleted_collected_classification_contents AS (
        DELETE FROM collected_classification_contents
        WHERE collected_classification_contents.classification_alias_id = ANY(ca_ids)
          AND NOT EXISTS (
            SELECT 1
            FROM new_collected_classification_contents
            WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id
              AND new_collected_classification_contents.relation = collected_classification_contents.relation
              AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id
          )
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type,
          hidden,
          relation
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type,
        new_collected_classification_contents.hidden,
        new_collected_classification_contents.relation
      FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type,
        hidden = EXCLUDED.hidden
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type
        OR collected_classification_contents.hidden IS DISTINCT
      FROM EXCLUDED.hidden;
      END IF;
      END; $$;

      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_contents.relation,
            c2.id
          ) classification_contents.content_data_id "thing_id",
          c2.id "classification_alias_id",
          c2.concept_scheme_id "classification_tree_label_id",
          concepts.id = c2.id "direct",
          c2.id = ANY (classification_alias_paths_transitive.hidden_ids) "hidden",
          classification_contents.relation,
          ROW_NUMBER() over (
            PARTITION by classification_contents.content_data_id,
            classification_alias_paths_transitive.id,
            c2.concept_scheme_id
            ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
          ) AS "row_number"
        FROM classification_contents
          JOIN concepts ON concepts.classification_id = classification_contents.classification_id
          JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id
          JOIN concepts c2 ON c2.id = ANY (
            classification_alias_paths_transitive.full_path_ids
          )
          JOIN classification_alias_paths cap ON cap.id = c2.id
        WHERE classification_contents.content_data_id = ANY (thing_ids)
        ORDER BY classification_contents.content_data_id,
          classification_contents.relation,
          c2.id,
          "direct" DESC,
          "hidden" ASC,
          "row_number"
      ),
      new_collected_classification_contents AS (
        SELECT full_classification_content_relations.thing_id,
          full_classification_content_relations.classification_alias_id,
          full_classification_content_relations.classification_tree_label_id,
          CASE
            WHEN full_classification_content_relations.direct THEN 'direct'
            WHEN full_classification_content_relations.row_number > 1 THEN 'broader'
            ELSE 'related'
          END AS "link_type",
          full_classification_content_relations.hidden,
          full_classification_content_relations.relation
        FROM full_classification_content_relations
      ),
      deleted_collected_classification_contents AS (
        DELETE FROM collected_classification_contents
        WHERE collected_classification_contents.thing_id = ANY(thing_ids)
          AND NOT EXISTS (
            SELECT 1
            FROM new_collected_classification_contents
            WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id
              AND new_collected_classification_contents.relation = collected_classification_contents.relation
              AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id
          )
      )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type,
          hidden,
          relation
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type,
        new_collected_classification_contents.hidden,
        new_collected_classification_contents.relation
      FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type,
        hidden = EXCLUDED.hidden
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type
        OR collected_classification_contents.hidden IS DISTINCT
      FROM EXCLUDED.hidden;
      END IF;
      END; $$;

      CREATE OR REPLACE FUNCTION public.generate_collected_classification_content_relations(
          content_ids uuid [],
          excluded_classification_ids uuid []
        ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(content_ids, 1) > 0 THEN WITH direct_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            FALSE "hidden",
            classification_contents.relation,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              classification_contents.classification_id,
              c2.concept_scheme_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN classification_alias_paths ON concepts.id = classification_alias_paths.id
            JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids)
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE classification_contents.content_data_id = ANY (content_ids)
          ORDER BY classification_contents.content_data_id,
            classification_contents.relation,
            c2.id,
            "row_number"
        ),
        related_classification_content_relations AS (
          SELECT DISTINCT ON (
              classification_contents.content_data_id,
              classification_contents.relation,
              c2.id
            ) classification_contents.content_data_id "thing_id",
            c2.id "classification_alias_id",
            c2.concept_scheme_id "classification_tree_label_id",
            concept_links.hidden "hidden",
            classification_contents.relation,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              concept_links.parent_id,
              c2.concept_scheme_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC,
              concept_links.hidden ASC
            ) AS "row_number"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN concept_links ON concepts.id = concept_links.child_id
            AND concept_links.link_type = 'related'
            JOIN classification_alias_paths ON concept_links.parent_id = classification_alias_paths.id
            JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids)
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE classification_contents.content_data_id = ANY (content_ids)
          ORDER BY classification_contents.content_data_id,
            classification_contents.relation,
            c2.id,
            "hidden",
            "row_number"
        ),
        full_classification_content_relations AS (
          SELECT *,
            CASE
              WHEN direct_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'direct'
            END AS "link_type"
          FROM direct_classification_content_relations
          UNION
          SELECT *,
            CASE
              WHEN related_classification_content_relations.row_number > 1 THEN 'broader'
              ELSE 'related'
            END AS "link_type"
          FROM related_classification_content_relations
        ),
        new_collected_classification_contents AS (
          SELECT DISTINCT ON (
              full_classification_content_relations.thing_id,
              full_classification_content_relations.relation,
              full_classification_content_relations.classification_alias_id
            ) full_classification_content_relations.thing_id,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.classification_tree_label_id,
            full_classification_content_relations.relation,
            full_classification_content_relations.link_type,
            full_classification_content_relations.hidden
          FROM full_classification_content_relations
          ORDER BY full_classification_content_relations.thing_id,
            full_classification_content_relations.relation,
            full_classification_content_relations.classification_alias_id,
            full_classification_content_relations.hidden ASC
        ),
        deleted_collected_classification_contents AS (
          DELETE FROM collected_classification_contents
          WHERE collected_classification_contents.thing_id = ANY(content_ids)
            AND NOT EXISTS (
              SELECT 1
              FROM new_collected_classification_contents
              WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id
                AND new_collected_classification_contents.relation = collected_classification_contents.relation
                AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id
            )
        )
      INSERT INTO collected_classification_contents (
          thing_id,
          classification_alias_id,
          classification_tree_label_id,
          link_type,
          hidden,
          relation
        )
      SELECT new_collected_classification_contents.thing_id,
        new_collected_classification_contents.classification_alias_id,
        new_collected_classification_contents.classification_tree_label_id,
        new_collected_classification_contents.link_type,
        new_collected_classification_contents.hidden,
        new_collected_classification_contents.relation
      FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO
      UPDATE
      SET classification_tree_label_id = EXCLUDED.classification_tree_label_id,
        link_type = EXCLUDED.link_type,
        hidden = EXCLUDED.hidden
      WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT
      FROM EXCLUDED.classification_tree_label_id
        OR collected_classification_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type
        OR collected_classification_contents.hidden IS DISTINCT
      FROM EXCLUDED.hidden;
      END IF;
      END; $$;
    SQL
  end

  def down
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_update_trigger ON public.classification_alias_paths_transitive;
      DROP FUNCTION IF EXISTS public.generate_ccc_relations_transitive_update_trigger_function();

      CREATE OR REPLACE FUNCTION public.upsert_ca_paths_transitive(concept_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths( id, parent_id, ancestor_ids, full_path_ids, full_path_names, link_types, tree_label_id ) AS ( SELECT c.id, cl.parent_id, ARRAY []::uuid [], ARRAY [c.id], ARRAY [c.internal_name], ARRAY [cl.link_type]::varchar [], c.concept_scheme_id FROM concepts c JOIN concept_links cl ON cl.child_id = c.id WHERE c.id = ANY(concept_ids) UNION ALL SELECT paths.id, cl.parent_id, ancestor_ids || c.id, full_path_ids || c.id, full_path_names || c.internal_name, CASE WHEN cl.parent_id IS NULL THEN paths.link_types ELSE paths.link_types || cl.link_type END, c.concept_scheme_id FROM concepts c JOIN paths ON paths.parent_id = c.id JOIN concept_links cl ON cl.child_id = c.id WHERE c.id <> ALL (paths.full_path_ids) ), child_paths( id, ancestor_ids, full_path_ids, full_path_names, link_types ) AS ( SELECT paths.id AS id, paths.ancestor_ids AS ancestor_ids, paths.full_path_ids AS full_path_ids, paths.full_path_names || cs.name AS full_path_names, paths.link_types AS link_types FROM paths JOIN concept_schemes cs ON cs.id = paths.tree_label_id WHERE paths.parent_id IS NULL UNION ALL SELECT c.id AS id, (cl.parent_id || p1.ancestor_ids) AS ancestors_ids, (c.id || p1.full_path_ids) AS full_path_ids, (c.internal_name || p1.full_path_names) AS full_path_names, (cl.link_type || p1.link_types) AS link_types FROM concepts c JOIN concept_links cl ON cl.child_id = c.id JOIN child_paths p1 ON p1.id = cl.parent_id WHERE c.id <> ALL (p1.full_path_ids) ), deleted_capt AS ( DELETE FROM classification_alias_paths_transitive WHERE classification_alias_paths_transitive.id IN ( SELECT capt.id FROM classification_alias_paths_transitive capt WHERE capt.full_path_ids && concept_ids AND NOT EXISTS ( SELECT 1 FROM child_paths WHERE child_paths.full_path_ids = capt.full_path_ids ) ORDER BY capt.id ASC FOR UPDATE SKIP LOCKED ) ) INSERT INTO classification_alias_paths_transitive ( classification_alias_id, ancestor_ids, full_path_ids, full_path_names, link_types ) SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id, child_paths.ancestor_ids, child_paths.full_path_ids, child_paths.full_path_names, array_remove(child_paths.link_types, NULL) FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO UPDATE SET full_path_names = EXCLUDED.full_path_names WHERE classification_alias_paths_transitive.full_path_names IS DISTINCT FROM EXCLUDED.full_path_names; END IF; END; $$;

      CREATE OR REPLACE FUNCTION public.concept_links_update_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concept_links.child_id)) FROM ( SELECT DISTINCT new_concept_links.child_id FROM old_concept_links JOIN new_concept_links ON old_concept_links.id = new_concept_links.id WHERE old_concept_links.child_id IS DISTINCT FROM new_concept_links.child_id OR old_concept_links.parent_id IS DISTINCT FROM new_concept_links.parent_id OR old_concept_links.link_type IS DISTINCT FROM new_concept_links.link_type ) "updated_concept_links"; RETURN NULL; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH full_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", concepts.id = c2.id "direct", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, classification_alias_paths_transitive.id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id JOIN concepts c2 ON c2.id = ANY ( classification_alias_paths_transitive.full_path_ids ) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE cap.full_path_ids && ca_ids ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "direct" DESC, "row_number" ), new_collected_classification_contents AS ( SELECT full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, CASE WHEN full_classification_content_relations.direct THEN 'direct' WHEN full_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type", full_classification_content_relations.relation FROM full_classification_content_relations WHERE full_classification_content_relations.classification_alias_id = ANY(ca_ids) ), deleted_collected_classification_contents AS ( DELETE FROM collected_classification_contents WHERE collected_classification_contents.classification_alias_id = ANY(ca_ids) AND NOT EXISTS ( SELECT 1 FROM new_collected_classification_contents WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id AND new_collected_classification_contents.relation = collected_classification_contents.relation AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, link_type, relation ) SELECT new_collected_classification_contents.thing_id, new_collected_classification_contents.classification_alias_id, new_collected_classification_contents.classification_tree_label_id, new_collected_classification_contents.link_type, new_collected_classification_contents.relation FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO UPDATE SET classification_tree_label_id = EXCLUDED.classification_tree_label_id, link_type = EXCLUDED.link_type WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT FROM EXCLUDED.classification_tree_label_id OR collected_classification_contents.link_type IS DISTINCT FROM EXCLUDED.link_type; END IF; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH full_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", concepts.id = c2.id "direct", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, classification_alias_paths_transitive.id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id JOIN concepts c2 ON c2.id = ANY ( classification_alias_paths_transitive.full_path_ids ) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE classification_contents.content_data_id = ANY (thing_ids) ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "direct" DESC, "row_number" ), new_collected_classification_contents AS ( SELECT full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, CASE WHEN full_classification_content_relations.direct THEN 'direct' WHEN full_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type", full_classification_content_relations.relation FROM full_classification_content_relations ), deleted_collected_classification_contents AS ( DELETE FROM collected_classification_contents WHERE collected_classification_contents.thing_id = ANY(thing_ids) AND NOT EXISTS ( SELECT 1 FROM new_collected_classification_contents WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id AND new_collected_classification_contents.relation = collected_classification_contents.relation AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, link_type, relation ) SELECT new_collected_classification_contents.thing_id, new_collected_classification_contents.classification_alias_id, new_collected_classification_contents.classification_tree_label_id, new_collected_classification_contents.link_type, new_collected_classification_contents.relation FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO UPDATE SET classification_tree_label_id = EXCLUDED.classification_tree_label_id, link_type = EXCLUDED.link_type WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT FROM EXCLUDED.classification_tree_label_id OR collected_classification_contents.link_type IS DISTINCT FROM EXCLUDED.link_type; END IF; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_collected_classification_content_relations( content_ids uuid [], excluded_classification_ids uuid [] ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(content_ids, 1) > 0 THEN WITH direct_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, classification_contents.classification_id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN classification_alias_paths ON concepts.id = classification_alias_paths.id JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE classification_contents.content_data_id = ANY (content_ids) ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "row_number" ), related_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, concept_links.parent_id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN concept_links ON concepts.id = concept_links.child_id AND concept_links.link_type = 'related' JOIN classification_alias_paths ON concept_links.parent_id = classification_alias_paths.id JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE classification_contents.content_data_id = ANY (content_ids) ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "row_number" ), full_classification_content_relations AS ( SELECT *, CASE WHEN direct_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'direct' END AS "link_type" FROM direct_classification_content_relations UNION SELECT *, CASE WHEN related_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type" FROM related_classification_content_relations ), new_collected_classification_contents AS ( SELECT DISTINCT ON ( full_classification_content_relations.thing_id, full_classification_content_relations.relation, full_classification_content_relations.classification_alias_id ) full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, full_classification_content_relations.relation, full_classification_content_relations.link_type FROM full_classification_content_relations ), deleted_collected_classification_contents AS ( DELETE FROM collected_classification_contents WHERE collected_classification_contents.thing_id = ANY(content_ids) AND NOT EXISTS ( SELECT 1 FROM new_collected_classification_contents WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id AND new_collected_classification_contents.relation = collected_classification_contents.relation AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, link_type, relation ) SELECT new_collected_classification_contents.thing_id, new_collected_classification_contents.classification_alias_id, new_collected_classification_contents.classification_tree_label_id, new_collected_classification_contents.link_type, new_collected_classification_contents.relation FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO UPDATE SET classification_tree_label_id = EXCLUDED.classification_tree_label_id, link_type = EXCLUDED.link_type WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT FROM EXCLUDED.classification_tree_label_id OR collected_classification_contents.link_type IS DISTINCT FROM EXCLUDED.link_type; END IF; END; $$;
    SQL
  end
end
