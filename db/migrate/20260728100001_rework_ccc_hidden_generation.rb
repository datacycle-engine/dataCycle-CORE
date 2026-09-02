# frozen_string_literal: true

# Redmine #50677: collected_classification_contents.hidden is no longer derived from a per-mapping
# flag but from the tree of the concept that is being collected:
#
#   hidden = <concept was reached through a mapping> AND <concept's tree has hidden_mappings>
#
# The first half is pure path structure, so the transitive path table carries it as `mapped_ids`
# (renamed from #47172's `hidden_ids`, which additionally required the mapping itself to be flagged).
# Consequences of splitting the two halves:
#
#   * chained mappings out of a flagged tree stay visible — only the flagged tree's own concepts are
#     hidden, not everything above them in the path,
#   * a direct classification from a flagged tree (and its broader ancestors) stays visible, because
#     it is not reached through a mapping,
#   * mapped_ids does not depend on the flag any more, so toggling it regenerates CCC without changing
#     a single path row (see ClassificationTreeLabel#refresh_hidden_mappings).
#
# The link-type array of an existing path row was never refreshed on conflict, which left stale
# link_types behind whenever a route changed (visible in production data as link_types that do not
# match the actual concept_links of the path). It is refreshed now — ClassificationAliasPathsTransitive
# .mapped_classification_aliases reads it positionally. Both halves of a path row can therefore be wrong
# on the way in, so `up` repairs every row whose mapped_ids or link_types disagree with the current
# concept_links (repair_stale_paths!) instead of only rematerialising the flagged trees: mapped_ids is
# documented as "reached through a mapping" and nothing else may be left holding #47172's narrower value.
# Not covered, deliberately: the over-long link_types of the shape bug described in
# path_and_ccc_functions. Neither condition can see the dangling entry above the root (both stop at the
# last concept that has a successor), and it is invisible to every reader, so those rows are left to be
# shortened by the next upsert that touches their path — which changes no mapped_ids and therefore does
# not cascade into CCC.
class ReworkCccHiddenGeneration < ActiveRecord::Migration[8.0]
  # The repair below can rewrite classification_alias_paths_transitive in full and cascade from there
  # into collected_classification_contents (see repair_stale_paths!). Running that as one statement in
  # one transaction would hold locks and accumulate WAL for its whole runtime and then throw all of it
  # away on any failure, so it is batched and each batch commits on its own. `up` and `down` are
  # idempotent — every step is guarded, CREATE OR REPLACE, or a recompute — so an interrupted run is
  # simply re-run. Until it is, though, the replaced functions are already committed and live while
  # the unrepaired rows still hold #47172's narrower mapped_ids: every content that reaches a concept
  # through a path the repair has not reached yet serves the wrong `hidden` in the meantime. Run this
  # off-hours, and to completion.
  disable_ddl_transaction!

  # roots, not leaves: one root pulls its entire subtree into the recursive CTE, so these batches are
  # small on purpose
  PATH_BATCH_SIZE = 50
  # plain id lists handed to the CCC generators
  CCC_BATCH_SIZE = 1_000
  # the mapped_ids expression of upsert_ca_paths_transitive, as a correlated subquery over an existing
  # `capt` row — a row whose stored value differs was written by an older function version. The stored
  # link_types is the very array the function indexes (see the NULL strip note on
  # path_and_ccc_functions), so the two cannot disagree on subscripts.
  EXPECTED_MAPPED_IDS = <<~SQL.squish
    SELECT COALESCE(ARRAY_AGG(capt.full_path_ids [i]), ARRAY []::uuid [])
    FROM generate_subscripts(capt.full_path_ids, 1) AS i
    WHERE EXISTS (
        SELECT 1
        FROM generate_subscripts(capt.link_types, 1) AS j
        WHERE j < i
          AND capt.link_types [j] = 'related'
      )
  SQL

  # link_types [i] is the concept_link from full_path_ids [i] up to full_path_ids [i + 1]; the entry
  # above the root (present only on rows written from a root concept, see the shape note in
  # path_and_ccc_functions) has no successor to check.
  UNBACKED_LINK_TYPES = <<~SQL.squish
    SELECT 1
    FROM generate_subscripts(capt.full_path_ids, 1) AS i
    WHERE i < CARDINALITY(capt.full_path_ids)
      AND NOT EXISTS (
        SELECT 1
        FROM concept_links cl
        WHERE cl.child_id = capt.full_path_ids [i]
          AND cl.parent_id = capt.full_path_ids [i + 1]
          AND cl.link_type = capt.link_types [i]
      )
  SQL

  def up
    if column_exists?(:classification_alias_paths_transitive, :hidden_ids)
      # keeps the current values as a seed: a concept above a hidden mapping is above a mapping.
      # repair_stale_paths! widens them to every concept above *any* mapping.
      rename_column :classification_alias_paths_transitive, :hidden_ids, :mapped_ids
    else
      add_column :classification_alias_paths_transitive, :mapped_ids, :uuid, array: true, default: [], null: false, if_not_exists: true
    end

    execute path_and_ccc_functions
    repair_stale_paths!("capt.mapped_ids IS DISTINCT FROM (#{EXPECTED_MAPPED_IDS}) OR EXISTS (#{UNBACKED_LINK_TYPES})")
    rematerialize_flagged_trees!
  end

  def down
    execute previous_path_and_ccc_functions

    rename_column :classification_alias_paths_transitive, :mapped_ids, :hidden_ids if column_exists?(:classification_alias_paths_transitive, :mapped_ids)

    # `up` widened hidden_ids to every concept above any mapping; #47172's function narrows it back to
    # the concepts above a *flagged* mapping, which 20260728100002 (already rolled back at this point)
    # re-derived onto concept_links.hidden. Every row that can hold a value carries a 'related' link.
    repair_stale_paths!("'related' = ANY(capt.link_types)")
    rematerialize_flagged_trees!
  end

  private

  # Re-runs the path upsert for every `capt` row matching `condition`, which rewrites the whole row from
  # its current concept_links. Fed the *root* of each stale path (the last entry of full_path_ids):
  # upsert_ca_paths_transitive walks its argument up to the roots and then back down to every descendant,
  # so one root rebuilds every path below it exactly once — feeding the stale leaves instead would
  # rebuild the same subtree once per leaf. A no-op without matches and without the feature.
  def repair_stale_paths!(condition)
    return unless DataCycleCore::Feature::TransitiveClassificationPath.enabled?

    root_ids = unbounded_select_values(<<~SQL.squish)
      SELECT DISTINCT capt.full_path_ids [CARDINALITY(capt.full_path_ids)]
      FROM classification_alias_paths_transitive capt
      WHERE #{condition}
    SQL

    each_batch(root_ids, PATH_BATCH_SIZE, 'repair transitive paths') do |ids|
      execute_unbounded('SELECT public.upsert_ca_paths_transitive(ARRAY[?]::uuid[])', ids)
    end
  end

  # A flagged tree's `hidden` values change without its path rows changing, so the CCC trigger (which
  # only fires on a mapped_ids change) does not cover them. Scoped to the flagged trees' own concepts,
  # the only ones whose `hidden` can differ. A no-op without a flagged tree.
  def rematerialize_flagged_trees!
    if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
      concept_ids = unbounded_select_values(<<~SQL.squish)
        SELECT c.id
        FROM concepts c
          JOIN concept_schemes cs ON cs.id = c.concept_scheme_id
        WHERE cs.hidden_mappings
      SQL

      each_batch(concept_ids, CCC_BATCH_SIZE, 'regenerate ccc of flagged trees') do |ids|
        execute_unbounded('SELECT public.generate_ccc_from_ca_ids_transitive(ARRAY[?]::uuid[])', ids)
      end
    else
      thing_ids = unbounded_select_values(<<~SQL.squish)
        SELECT DISTINCT cc.content_data_id
        FROM classification_contents cc
          JOIN concepts src ON src.classification_id = cc.classification_id
          JOIN concept_links cl ON cl.child_id = src.id
          AND cl.link_type = 'related'
          JOIN concepts tgt ON tgt.id = cl.parent_id
          JOIN concept_schemes cs ON cs.id = tgt.concept_scheme_id
          AND cs.hidden_mappings
      SQL

      each_batch(thing_ids, CCC_BATCH_SIZE, 'regenerate ccc of flagged trees') do |ids|
        execute_unbounded('SELECT public.generate_collected_classification_content_relations(ARRAY[?]::uuid[], ARRAY[]::uuid[])', ids)
      end
    end
  end

  def each_batch(ids, size, label)
    return if ids.blank?

    batches = ids.each_slice(size).to_a

    batches.each_with_index do |batch, index|
      say_with_time("#{label} (#{index + 1}/#{batches.size}, #{ids.size} ids)") { yield batch }
    end
  end

  # One transaction per call: disable_ddl_transaction! means there is no surrounding one, so this is
  # what scopes SET LOCAL and what commits a batch's work before the next one starts. The discovery
  # queries need the timeout lifted as much as the upserts do: statement_timeout is 1min in the
  # shipped config/database.yml, and they scan the whole path table with a nested generate_subscripts
  # per row.
  def unbounded
    ActiveRecord::Base.transaction do
      execute('SET LOCAL statement_timeout = 0')
      yield
    end
  end

  def execute_unbounded(sql, ids)
    unbounded { execute(ActiveRecord::Base.sanitize_sql([sql, ids])) }
  end

  def unbounded_select_values(sql)
    unbounded { select_values(sql) }
  end

  # Tiebreaker note: `hidden` used to be concept_links.hidden, which could differ between two mappings
  # sharing a parent, so it tiebroke the row_number window and the DISTINCT ON of
  # related_classification_content_relations. There it is now a function of c2's own tree, which is part
  # of both keys, so it is constant within every group and both terms are dropped. The remaining ones
  # all still decide something: new_collected_classification_contents keeps direct (never hidden) over
  # related, and in the transitive functions `hidden` also depends on capt.mapped_ids, which varies
  # between the path rows of one (thing, relation, c2) — so their DISTINCT ON keeps preferring the row
  # that reaches c2 without a mapping.
  #
  # Shape note: link_types [i] is the link from full_path_ids [i] up to full_path_ids [i + 1], so a
  # complete path has one entry fewer than it has concepts — the root has nothing above it. The
  # recursive step already drops that dangling link (`WHEN cl.parent_id IS NULL THEN paths.link_types`),
  # but the base case used to keep it whenever the walk *started* at a root, so the same path was stored
  # with either length depending on which concept triggered the upsert. Harmless to every reader (both
  # `mapped_ids` and .mapped_classification_aliases only ever index below the root), but now that
  # link_types takes part in the ON CONFLICT it would make those rows flip-flop on every upsert. The
  # base case drops it too, so the length is a function of the path alone.
  #
  # NULL strip note: link_types loses its NULLs once, in the child_paths base case, so the array the
  # mapped_ids subquery indexes is the one that ends up stored — which is what lets EXPECTED_MAPPED_IDS
  # mirror it from capt.link_types. Vestigial either way: concept_links.link_type is NOT NULL
  # (20240325085848), so nothing is ever removed.
  def path_and_ccc_functions
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.upsert_ca_paths_transitive(concept_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths(
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
          CASE
            WHEN cl.parent_id IS NULL THEN ARRAY []::varchar []
            ELSE ARRAY [cl.link_type]::varchar []
          END,
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
        SELECT paths.id,
          paths.ancestor_ids,
          paths.full_path_ids,
          paths.full_path_names || cs.name,
          array_remove(paths.link_types, NULL)
        FROM paths
          JOIN concept_schemes cs ON cs.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT c.id,
          cl.parent_id || p1.ancestor_ids,
          c.id || p1.full_path_ids,
          c.internal_name || p1.full_path_names,
          cl.link_type || p1.link_types
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
          mapped_ids
        )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id,
        child_paths.ancestor_ids,
        child_paths.full_path_ids,
        child_paths.full_path_names,
        child_paths.link_types,
        (
          SELECT COALESCE(array_agg(child_paths.full_path_ids [i]), ARRAY []::uuid [])
          FROM generate_subscripts(child_paths.full_path_ids, 1) AS i
          WHERE EXISTS (
              SELECT 1
              FROM generate_subscripts(child_paths.link_types, 1) AS j
              WHERE j < i
                AND child_paths.link_types [j] = 'related'
            )
        )
      FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO
      UPDATE
      SET full_path_names = EXCLUDED.full_path_names,
        link_types = EXCLUDED.link_types,
        mapped_ids = EXCLUDED.mapped_ids
      WHERE classification_alias_paths_transitive.full_path_names IS DISTINCT
      FROM EXCLUDED.full_path_names
        OR classification_alias_paths_transitive.link_types IS DISTINCT
      FROM EXCLUDED.link_types
        OR classification_alias_paths_transitive.mapped_ids IS DISTINCT
      FROM EXCLUDED.mapped_ids;
      END IF;
      END; $$;

      CREATE OR REPLACE FUNCTION public.concept_links_update_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concept_links.child_id)) FROM ( SELECT DISTINCT new_concept_links.child_id FROM old_concept_links JOIN new_concept_links ON old_concept_links.id = new_concept_links.id WHERE old_concept_links.child_id IS DISTINCT FROM new_concept_links.child_id OR old_concept_links.parent_id IS DISTINCT FROM new_concept_links.parent_id OR old_concept_links.link_type IS DISTINCT FROM new_concept_links.link_type ) "updated_concept_links"; RETURN NULL; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_relations_transitive_update_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM public.generate_ccc_from_ca_ids_transitive (array_agg(cccra.id)) FROM ( SELECT DISTINCT ca.id FROM new_classification_alias_paths_transitive ncapt JOIN old_classification_alias_paths_transitive ocapt ON ocapt.id = ncapt.id JOIN classification_aliases ca ON ca.id = ANY (ncapt.full_path_ids) AND ca.deleted_at IS NULL WHERE ncapt.mapped_ids IS DISTINCT FROM ocapt.mapped_ids ) "cccra"; RETURN NULL; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH full_classification_content_relations AS (
        SELECT DISTINCT ON (
            classification_contents.content_data_id,
            classification_contents.relation,
            c2.id
          ) classification_contents.content_data_id "thing_id",
          c2.id "classification_alias_id",
          c2.concept_scheme_id "classification_tree_label_id",
          concepts.id = c2.id "direct",
          c2.id = ANY (classification_alias_paths_transitive.mapped_ids)
          AND COALESCE(cs2.hidden_mappings, FALSE) "hidden",
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
          LEFT OUTER JOIN concept_schemes cs2 ON cs2.id = c2.concept_scheme_id
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
          c2.id = ANY (classification_alias_paths_transitive.mapped_ids)
          AND COALESCE(cs2.hidden_mappings, FALSE) "hidden",
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
          LEFT OUTER JOIN concept_schemes cs2 ON cs2.id = c2.concept_scheme_id
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
            COALESCE(cs2.hidden_mappings, FALSE) "hidden",
            classification_contents.relation,
            ROW_NUMBER() over (
              PARTITION by classification_contents.content_data_id,
              concept_links.parent_id,
              c2.concept_scheme_id
              ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC
            ) AS "row_number"
          FROM classification_contents
            JOIN concepts ON concepts.classification_id = classification_contents.classification_id
            JOIN concept_links ON concepts.id = concept_links.child_id
            AND concept_links.link_type = 'related'
            JOIN classification_alias_paths ON concept_links.parent_id = classification_alias_paths.id
            JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids)
            LEFT OUTER JOIN concept_schemes cs2 ON cs2.id = c2.concept_scheme_id
            JOIN classification_alias_paths cap ON cap.id = c2.id
          WHERE classification_contents.content_data_id = ANY (content_ids)
          ORDER BY classification_contents.content_data_id,
            classification_contents.relation,
            c2.id,
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

  # #47172 versions: per-mapping flag carried through concept_links.hidden and hidden_ids.
  def previous_path_and_ccc_functions
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.upsert_ca_paths_transitive(concept_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(concept_ids, 1) > 0 THEN WITH RECURSIVE paths( id, parent_id, ancestor_ids, full_path_ids, full_path_names, link_types, link_hidden, tree_label_id ) AS ( SELECT c.id, cl.parent_id, ARRAY []::uuid [], ARRAY [c.id], ARRAY [c.internal_name], ARRAY [cl.link_type]::varchar [], ARRAY [cl.link_type = 'related' AND cl.hidden]::boolean [], c.concept_scheme_id FROM concepts c JOIN concept_links cl ON cl.child_id = c.id WHERE c.id = ANY(concept_ids) UNION ALL SELECT paths.id, cl.parent_id, ancestor_ids || c.id, full_path_ids || c.id, full_path_names || c.internal_name, CASE WHEN cl.parent_id IS NULL THEN paths.link_types ELSE paths.link_types || cl.link_type END, CASE WHEN cl.parent_id IS NULL THEN paths.link_hidden ELSE paths.link_hidden || (cl.link_type = 'related' AND cl.hidden) END, c.concept_scheme_id FROM concepts c JOIN paths ON paths.parent_id = c.id JOIN concept_links cl ON cl.child_id = c.id WHERE c.id <> ALL (paths.full_path_ids) ), child_paths( id, ancestor_ids, full_path_ids, full_path_names, link_types, link_hidden ) AS ( SELECT paths.id, paths.ancestor_ids, paths.full_path_ids, paths.full_path_names || cs.name, paths.link_types, paths.link_hidden FROM paths JOIN concept_schemes cs ON cs.id = paths.tree_label_id WHERE paths.parent_id IS NULL UNION ALL SELECT c.id, cl.parent_id || p1.ancestor_ids, c.id || p1.full_path_ids, c.internal_name || p1.full_path_names, cl.link_type || p1.link_types, (cl.link_type = 'related' AND cl.hidden) || p1.link_hidden FROM concepts c JOIN concept_links cl ON cl.child_id = c.id JOIN child_paths p1 ON p1.id = cl.parent_id WHERE c.id <> ALL (p1.full_path_ids) ), deleted_capt AS ( DELETE FROM classification_alias_paths_transitive WHERE classification_alias_paths_transitive.id IN ( SELECT capt.id FROM classification_alias_paths_transitive capt WHERE capt.full_path_ids && concept_ids AND NOT EXISTS ( SELECT 1 FROM child_paths WHERE child_paths.full_path_ids = capt.full_path_ids ) ORDER BY capt.id ASC FOR UPDATE SKIP LOCKED ) ) INSERT INTO classification_alias_paths_transitive ( classification_alias_id, ancestor_ids, full_path_ids, full_path_names, link_types, hidden_ids ) SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id, child_paths.ancestor_ids, child_paths.full_path_ids, child_paths.full_path_names, array_remove(child_paths.link_types, NULL), ( SELECT COALESCE(array_agg(child_paths.full_path_ids [i]), ARRAY []::uuid []) FROM generate_subscripts(child_paths.full_path_ids, 1) AS i WHERE EXISTS ( SELECT 1 FROM generate_subscripts(child_paths.link_hidden, 1) AS j WHERE j < i AND child_paths.link_hidden [j] ) ) FROM child_paths ON CONFLICT ON CONSTRAINT classification_alias_paths_transitive_unique DO UPDATE SET full_path_names = EXCLUDED.full_path_names, hidden_ids = EXCLUDED.hidden_ids WHERE classification_alias_paths_transitive.full_path_names IS DISTINCT FROM EXCLUDED.full_path_names OR classification_alias_paths_transitive.hidden_ids IS DISTINCT FROM EXCLUDED.hidden_ids; END IF; END; $$;

      CREATE OR REPLACE FUNCTION public.concept_links_update_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM upsert_ca_paths_transitive (ARRAY_AGG(updated_concept_links.child_id)) FROM ( SELECT DISTINCT new_concept_links.child_id FROM old_concept_links JOIN new_concept_links ON old_concept_links.id = new_concept_links.id WHERE old_concept_links.child_id IS DISTINCT FROM new_concept_links.child_id OR old_concept_links.parent_id IS DISTINCT FROM new_concept_links.parent_id OR old_concept_links.link_type IS DISTINCT FROM new_concept_links.link_type OR old_concept_links.hidden IS DISTINCT FROM new_concept_links.hidden ) "updated_concept_links"; RETURN NULL; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_relations_transitive_update_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN PERFORM public.generate_ccc_from_ca_ids_transitive (array_agg(cccra.id)) FROM ( SELECT DISTINCT ca.id FROM new_classification_alias_paths_transitive ncapt JOIN old_classification_alias_paths_transitive ocapt ON ocapt.id = ncapt.id JOIN classification_aliases ca ON ca.id = ANY (ncapt.full_path_ids) AND ca.deleted_at IS NULL WHERE ncapt.hidden_ids IS DISTINCT FROM ocapt.hidden_ids ) "cccra"; RETURN NULL; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_from_ca_ids_transitive(ca_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(ca_ids, 1) > 0 THEN WITH full_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", concepts.id = c2.id "direct", c2.id = ANY (classification_alias_paths_transitive.hidden_ids) "hidden", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, classification_alias_paths_transitive.id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id JOIN concepts c2 ON c2.id = ANY ( classification_alias_paths_transitive.full_path_ids ) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE cap.full_path_ids && ca_ids ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "direct" DESC, "hidden" ASC, "row_number" ), new_collected_classification_contents AS ( SELECT full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, CASE WHEN full_classification_content_relations.direct THEN 'direct' WHEN full_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type", full_classification_content_relations.hidden, full_classification_content_relations.relation FROM full_classification_content_relations WHERE full_classification_content_relations.classification_alias_id = ANY(ca_ids) ), deleted_collected_classification_contents AS ( DELETE FROM collected_classification_contents WHERE collected_classification_contents.classification_alias_id = ANY(ca_ids) AND NOT EXISTS ( SELECT 1 FROM new_collected_classification_contents WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id AND new_collected_classification_contents.relation = collected_classification_contents.relation AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, link_type, hidden, relation ) SELECT new_collected_classification_contents.thing_id, new_collected_classification_contents.classification_alias_id, new_collected_classification_contents.classification_tree_label_id, new_collected_classification_contents.link_type, new_collected_classification_contents.hidden, new_collected_classification_contents.relation FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO UPDATE SET classification_tree_label_id = EXCLUDED.classification_tree_label_id, link_type = EXCLUDED.link_type, hidden = EXCLUDED.hidden WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT FROM EXCLUDED.classification_tree_label_id OR collected_classification_contents.link_type IS DISTINCT FROM EXCLUDED.link_type OR collected_classification_contents.hidden IS DISTINCT FROM EXCLUDED.hidden; END IF; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_collected_cl_content_relations_transitive(thing_ids uuid []) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(thing_ids, 1) > 0 THEN WITH full_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", concepts.id = c2.id "direct", c2.id = ANY (classification_alias_paths_transitive.hidden_ids) "hidden", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, classification_alias_paths_transitive.id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN classification_alias_paths_transitive ON concepts.id = classification_alias_paths_transitive.classification_alias_id JOIN concepts c2 ON c2.id = ANY ( classification_alias_paths_transitive.full_path_ids ) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE classification_contents.content_data_id = ANY (thing_ids) ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "direct" DESC, "hidden" ASC, "row_number" ), new_collected_classification_contents AS ( SELECT full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, CASE WHEN full_classification_content_relations.direct THEN 'direct' WHEN full_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type", full_classification_content_relations.hidden, full_classification_content_relations.relation FROM full_classification_content_relations ), deleted_collected_classification_contents AS ( DELETE FROM collected_classification_contents WHERE collected_classification_contents.thing_id = ANY(thing_ids) AND NOT EXISTS ( SELECT 1 FROM new_collected_classification_contents WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id AND new_collected_classification_contents.relation = collected_classification_contents.relation AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, link_type, hidden, relation ) SELECT new_collected_classification_contents.thing_id, new_collected_classification_contents.classification_alias_id, new_collected_classification_contents.classification_tree_label_id, new_collected_classification_contents.link_type, new_collected_classification_contents.hidden, new_collected_classification_contents.relation FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO UPDATE SET classification_tree_label_id = EXCLUDED.classification_tree_label_id, link_type = EXCLUDED.link_type, hidden = EXCLUDED.hidden WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT FROM EXCLUDED.classification_tree_label_id OR collected_classification_contents.link_type IS DISTINCT FROM EXCLUDED.link_type OR collected_classification_contents.hidden IS DISTINCT FROM EXCLUDED.hidden; END IF; END; $$;

      CREATE OR REPLACE FUNCTION public.generate_collected_classification_content_relations( content_ids uuid [], excluded_classification_ids uuid [] ) RETURNS void LANGUAGE plpgsql AS $$ BEGIN IF array_length(content_ids, 1) > 0 THEN WITH direct_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", FALSE "hidden", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, classification_contents.classification_id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN classification_alias_paths ON concepts.id = classification_alias_paths.id JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE classification_contents.content_data_id = ANY (content_ids) ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "row_number" ), related_classification_content_relations AS ( SELECT DISTINCT ON ( classification_contents.content_data_id, classification_contents.relation, c2.id ) classification_contents.content_data_id "thing_id", c2.id "classification_alias_id", c2.concept_scheme_id "classification_tree_label_id", concept_links.hidden "hidden", classification_contents.relation, ROW_NUMBER() over ( PARTITION by classification_contents.content_data_id, concept_links.parent_id, c2.concept_scheme_id ORDER BY ARRAY_REVERSE(cap.full_path_ids) DESC, concept_links.hidden ASC ) AS "row_number" FROM classification_contents JOIN concepts ON concepts.classification_id = classification_contents.classification_id JOIN concept_links ON concepts.id = concept_links.child_id AND concept_links.link_type = 'related' JOIN classification_alias_paths ON concept_links.parent_id = classification_alias_paths.id JOIN concepts c2 ON c2.id = ANY (classification_alias_paths.full_path_ids) JOIN classification_alias_paths cap ON cap.id = c2.id WHERE classification_contents.content_data_id = ANY (content_ids) ORDER BY classification_contents.content_data_id, classification_contents.relation, c2.id, "hidden", "row_number" ), full_classification_content_relations AS ( SELECT *, CASE WHEN direct_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'direct' END AS "link_type" FROM direct_classification_content_relations UNION SELECT *, CASE WHEN related_classification_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type" FROM related_classification_content_relations ), new_collected_classification_contents AS ( SELECT DISTINCT ON ( full_classification_content_relations.thing_id, full_classification_content_relations.relation, full_classification_content_relations.classification_alias_id ) full_classification_content_relations.thing_id, full_classification_content_relations.classification_alias_id, full_classification_content_relations.classification_tree_label_id, full_classification_content_relations.relation, full_classification_content_relations.link_type, full_classification_content_relations.hidden FROM full_classification_content_relations ORDER BY full_classification_content_relations.thing_id, full_classification_content_relations.relation, full_classification_content_relations.classification_alias_id, full_classification_content_relations.hidden ASC ), deleted_collected_classification_contents AS ( DELETE FROM collected_classification_contents WHERE collected_classification_contents.thing_id = ANY(content_ids) AND NOT EXISTS ( SELECT 1 FROM new_collected_classification_contents WHERE new_collected_classification_contents.thing_id = collected_classification_contents.thing_id AND new_collected_classification_contents.relation = collected_classification_contents.relation AND new_collected_classification_contents.classification_alias_id = collected_classification_contents.classification_alias_id ) ) INSERT INTO collected_classification_contents ( thing_id, classification_alias_id, classification_tree_label_id, link_type, hidden, relation ) SELECT new_collected_classification_contents.thing_id, new_collected_classification_contents.classification_alias_id, new_collected_classification_contents.classification_tree_label_id, new_collected_classification_contents.link_type, new_collected_classification_contents.hidden, new_collected_classification_contents.relation FROM new_collected_classification_contents ON CONFLICT (thing_id, relation, classification_alias_id) DO UPDATE SET classification_tree_label_id = EXCLUDED.classification_tree_label_id, link_type = EXCLUDED.link_type, hidden = EXCLUDED.hidden WHERE collected_classification_contents.classification_tree_label_id IS DISTINCT FROM EXCLUDED.classification_tree_label_id OR collected_classification_contents.link_type IS DISTINCT FROM EXCLUDED.link_type OR collected_classification_contents.hidden IS DISTINCT FROM EXCLUDED.hidden; END IF; END; $$;
    SQL
  end
end
