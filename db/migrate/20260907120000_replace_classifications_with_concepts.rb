# frozen_string_literal: true

# Redmine #41458: `classifications`, `classification_aliases`, `classification_groups`,
# `classification_trees` and `classification_tree_labels` go away, and `concepts` stops being the
# read-only projection of them.
#
# One migration, therefore one transaction - the way back is the dump the deploy takes anyway, so
# there is no `down`. The step order is forced: the history backfill and both content rebuilds read
# the legacy tables, the rebuilds join over `concepts.classification_id`, and a trigger function can
# only be replaced once the tables it names carry their new names.
class ReplaceClassificationsWithConcepts < ActiveRecord::Migration[8.0]
  LEGACY_TABLES = [
    'classification_groups',
    'classification_trees',
    'classification_aliases',
    'classifications',
    'classification_tree_labels'
  ].freeze

  RENAMED_TABLES = {
    'collected_classification_contents' => 'collected_concept_contents',
    'classification_alias_paths' => 'concept_paths',
    'classification_alias_paths_transitive' => 'concept_paths_transitive',
    'classification_polygons' => 'concept_polygons',
    'classification_user_groups' => 'concept_user_groups'
  }.freeze

  # Every table lock_out_concurrent_writers takes AccessExclusive on: the two lists above, which
  # this migration drops and renames, plus the ones it rewrites in place. They are ordered as the
  # app writes them - the classification first, then the `concepts` row its projection trigger
  # follows with - so that the migration never holds `concepts` while it waits for
  # `classification_aliases`. Moving the concept_* names in front of the classification_* ones is
  # what would restore the cycle job 598691 died in. `things` is absent on purpose, locked below.
  REWRITTEN_TABLES = [
    *LEGACY_TABLES,
    *RENAMED_TABLES.keys,
    'classification_contents',
    'classification_content_histories',
    'concepts',
    'concept_schemes',
    'concept_links',
    'concept_histories',
    'concept_scheme_histories',
    'concept_link_histories'
  ].freeze

  # Renaming a table leaves its index names behind. Every name below is renamed with IF EXISTS, so
  # it does not matter which of them `rename_table`/`rename_column` already covered.
  RENAMED_INDEXES = {
    'collected_classification_contents_pkey' => 'collected_concept_contents_pkey',
    'ccc_ca_id_t_id_hidden_idx' => 'ccc_concept_id_thing_id_hidden_idx',
    'ccc_ctl_id_t_id_cai_idx' => 'ccc_concept_scheme_id_thing_id_idx',
    'ccc_unique_thing_id_classification_alias_id_idx' => 'ccc_unique_thing_id_concept_id_idx',
    'classification_alias_paths_pkey' => 'concept_paths_pkey',
    'classification_alias_paths_full_path_ids' => 'concept_paths_full_path_ids',
    'classification_alias_paths_on_full_path_names_idx' => 'concept_paths_on_full_path_names_idx',
    'index_classification_alias_paths_on_ancestor_ids' => 'index_concept_paths_on_ancestor_ids',
    'classification_alias_paths_transitive_pkey' => 'concept_paths_transitive_pkey',
    'classification_alias_paths_transitive_unique' => 'concept_paths_transitive_unique',
    'classification_alias_paths_transitive_full_path_ids' => 'concept_paths_transitive_full_path_ids',
    'capt_classification_alias_id_idx' => 'concept_paths_transitive_concept_id_idx',
    'classification_polygons_pkey' => 'concept_polygons_pkey',
    'classification_polygons_classification_alias_id_id_idx' => 'concept_polygons_concept_id_id_idx',
    'classification_polygons_geom_idx' => 'concept_polygons_geom_idx',
    'index_classification_polygons_on_geom_simple' => 'index_concept_polygons_on_geom_simple',
    'classification_user_groups_pkey' => 'concept_user_groups_pkey',
    'index_classification_user_groups_on_classification_id' => 'index_concept_user_groups_on_concept_id',
    'index_classification_user_groups_on_user_group_id' => 'index_concept_user_groups_on_user_group_id'
  }.freeze

  # The projection layer, plus the order_a and tree-label maintenance that hung off the legacy
  # tables. All of it is replaced by triggers on `concepts` and `concept_links`.
  PROJECTION_FUNCTIONS = [
    'insert_concepts_trigger_function',
    'update_concepts_trigger_function',
    'delete_concepts_trigger_function',
    'insert_concept_schemes_trigger_function',
    'update_concept_schemes_trigger_function',
    'delete_concept_schemes_trigger_function',
    'insert_concept_links_trees_trigger_function',
    'update_concept_links_trees_trigger_function',
    'delete_concept_links_trees_trigger_function',
    'delete_concept_links_trees_trigger_function2',
    'update_concept_links_groups_trigger_function',
    'delete_concept_links_groups_trigger_function',
    'delete_concept_links_groups_trigger_function2',
    'upsert_concept_tables_trigger_function',
    'update_classification_tree_tree_label_id', # -> concepts_propagate_scheme_trigger_function
    'update_classification_tree_tree_label_id_trigger',
    'update_classification_tree_tree_label_id_concept_trigger',
    'update_classification_aliases_order_a',
    'update_classification_aliases_order_a_trigger',
    'update_classification_trees_order_a_trigger',
    'insert_classification_trees_order_a_trigger'
  ].freeze

  # Renamed, and simplified where the hop over a classification fell away. The old name is dropped
  # once every caller points at the new one.
  RENAMED_FUNCTIONS = [
    'generate_collected_classification_content_relations',
    'generate_collected_classification_content_relations_trigger_1',
    'generate_collected_classification_content_relations_trigger_2',
    'generate_collected_classification_content_relations_trigger_3',
    'generate_collected_classification_content_relations_trigger_5',
    'generate_collected_cl_content_relations_transitive',
    'generate_ccc_from_ca_ids_transitive',
    'upsert_ca_paths',
    'upsert_ca_paths_transitive',
    'to_classification_content_history'
  ].freeze

  def up
    lift_statement_timeout
    lock_out_concurrent_writers
    backfill_projection_gaps
    drop_polygons_of_deleted_aliases
    verify_rebuild_preconditions!
    backfill_histories
    drop_legacy_ccc_triggers
    build_concept_contents
    remap_user_group_concepts
    purge_stale_transitive_paths
    purge_stale_collected_contents
    drop_projection_columns
    widen_external_key_index
    rename_satellite_tables
    rename_search_columns
    drop_legacy_tables
    replace_trigger_functions
    create_triggers
    apply_transitive_trigger_state
    drop_obsolete_functions
    rewrite_job_arguments
  end

  # The rollback is the dump taken by the deploy this migration is part of.
  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # config/database.yml gives every connection a statement_timeout of 1min, and PostgreSQL measures
  # it per statement rather than per execute. build_concept_contents sends one batch whose
  # statements added up to 114.5s in job 598691 without any of them tripping it; job 598878 died in
  # that same batch once the INSERT copying classification_contents crossed 60s on its own. Neither
  # run was near a limit it could be kept under - the copy is one statement over the whole table -
  # so the migration lifts the timeout the way the 23 others facing it do.
  #
  # It goes before lock_out_concurrent_writers so that the wait for those locks answers to
  # lock_timeout alone, rather than to whichever of the two one-minute clocks ran out first.
  def lift_statement_timeout
    execute 'SET LOCAL statement_timeout = 0'
  end

  # The steps below rewrite the classification tables for minutes inside one transaction, and the
  # deploy stops `jobs` but leaves `web` serving. An editor saving a classification then holds
  # RowExclusive on `classification_aliases` while the projection trigger waits for `concepts`,
  # which drop_projection_columns holds AccessExclusive: job 598691 deadlocked on exactly that pair
  # two minutes in, and took every step before it down with the transaction.
  #
  # Taking the locks first makes such a writer queue at the door instead of half-way through. It
  # does not rule out a deadlock while they are still being acquired, but one there costs a retry
  # rather than the whole body, and lock_timeout bounds a wait that the locks already taken have
  # blocked the app behind anyway. `things` is locked on its own, in the weaker mode the ADD
  # FOREIGN KEY in build_concept_contents needs there: AccessExclusive would stop reads too, and
  # with them the `curl 127.0.0.1:9293/stats` the web container is declared healthy by.
  #
  # lock_timeout stays in force for the rest of the transaction on purpose. It bounds waiting for a
  # lock, never a statement's own runtime, so the two minutes build_concept_contents spends copying
  # are no more at risk than before; what it does cover is the UPDATE rewrite_job_arguments runs
  # against solid_queue_jobs, which `scheduler` keeps writing because the deploy stops only `jobs`.
  def lock_out_concurrent_writers
    execute "SET LOCAL lock_timeout = '1min'"
    execute 'LOCK TABLE things IN SHARE ROW EXCLUSIVE MODE'
    execute "LOCK TABLE #{REWRITTEN_TABLES.join(', ')} IN ACCESS EXCLUSIVE MODE"
  end

  # `concepts` was filled once by 20240326094944 and has been kept in step since by the insert
  # triggers on `classification_aliases` and `classification_tree_labels`, so a live row that the
  # prefill's own WHERE clause skipped in 2024 has had nothing to put it there since. vtg prod
  # carries 34 such aliases and one such scheme.
  #
  # The gap has to close before the cut rather than after it: drop_legacy_tables takes
  # `classification_aliases` with it, and 24 of those aliases are the municipalities of the
  # `Bregenzerwald` scheme - live, in a live tree, primary for a live classification - each owning
  # a `classification_polygons` row that verify_rebuild_preconditions! would otherwise abort on.
  #
  # The four statements restate the prefill's rule rather than inventing a second one, which is why
  # an alias primary for no classification still gets no concept: the prefill's `groups` CTE
  # skipped those too (vtg: 10 duplicate `POI - Kategorien` entries, each sharing its
  # classification with the like-named alias that is primary and does have a concept). Where they
  # depart from it they follow what the rest of this migration already does: timestamps come off
  # the source row as in backfill_histories, so a concept for an alias created in 2021 does not
  # claim to have been created by the deploy; the `related` link skips an alias paired with
  # itself, the self-link backfill_histories gives the same reason for leaving out; and the tree
  # join takes live edges only, so an alias whose tree row was soft-deleted gets no concept naming
  # a scheme it no longer sits in.
  def backfill_projection_gaps
    scheme_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concept_schemes (
        id, name, external_system_id, external_key, internal, mappable, hidden_mappings,
        visibility, change_behaviour, created_at, updated_at
      )
      SELECT ctl.id, ctl.name, ctl.external_source_id, ctl.external_key, ctl.internal,
        ctl.mappable, ctl.hidden_mappings, ctl.visibility, ctl.change_behaviour,
        ctl.created_at, ctl.updated_at
      FROM classification_tree_labels ctl
      WHERE ctl.deleted_at IS NULL
      ON CONFLICT (id) DO NOTHING
    SQL

    concept_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concepts (
        id, internal_name, name_i18n, description_i18n, external_system_id, external_key,
        concept_scheme_id, order_a, assignable, internal, uri, ui_configs, classification_id,
        created_at, updated_at
      )
      SELECT ca.id, ca.internal_name, COALESCE(ca.name_i18n, '{}'), COALESCE(ca.description_i18n, '{}'),
        COALESCE(ca.external_source_id, cl.external_source_id),
        COALESCE(ca.external_key, cl.external_key),
        ct.classification_tree_label_id, ca.order_a, ca.assignable, ca.internal,
        COALESCE(ca.uri, cl.uri), COALESCE(ca.ui_configs, '{}'), cl.id,
        ca.created_at, ca.updated_at
      FROM classification_aliases ca
      JOIN classification_trees ct ON ct.classification_alias_id = ca.id AND ct.deleted_at IS NULL
      JOIN primary_classification_groups pcg ON pcg.classification_alias_id = ca.id AND pcg.deleted_at IS NULL
      JOIN classifications cl ON cl.id = pcg.classification_id AND cl.deleted_at IS NULL
      WHERE ca.deleted_at IS NULL
      ON CONFLICT (id) DO NOTHING
    SQL

    broader_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concept_links (parent_id, child_id, link_type)
      SELECT ct.parent_classification_alias_id, ct.classification_alias_id, 'broader'
      FROM classification_trees ct
      WHERE ct.deleted_at IS NULL
        AND EXISTS (SELECT 1 FROM concepts c WHERE c.id = ct.classification_alias_id)
        AND (
          ct.parent_classification_alias_id IS NULL
          OR EXISTS (SELECT 1 FROM concepts p WHERE p.id = ct.parent_classification_alias_id)
        )
      ON CONFLICT DO NOTHING
    SQL

    related_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concept_links (parent_id, child_id, link_type)
      SELECT cg.classification_alias_id, pcg.classification_alias_id, 'related'
      FROM classification_groups cg
      JOIN primary_classification_groups pcg ON pcg.classification_id = cg.classification_id
        AND pcg.deleted_at IS NULL
      WHERE cg.deleted_at IS NULL
        AND pcg.classification_alias_id <> cg.classification_alias_id
        AND EXISTS (SELECT 1 FROM concepts c WHERE c.id = cg.classification_alias_id)
        AND EXISTS (SELECT 1 FROM concepts p WHERE p.id = pcg.classification_alias_id)
      ON CONFLICT DO NOTHING
    SQL

    say "backfilled #{scheme_rows} concept schemes, #{concept_rows} concepts and #{broader_rows + related_rows} concept links the projection never created"
  end

  # A `classification_polygons` row outlives the soft-delete of its alias: its foreign key points at
  # `classification_aliases`, which keeps soft-deleted rows. The projection gives a soft-deleted
  # alias no concept, so the `add_foreign_key :concept_polygons, :concepts, on_delete: :cascade` in
  # rename_satellite_tables is what first rejects such a row - and that cascade is the rule it is
  # judged by, the one Concept::History already documents as why a deleted concept has an empty
  # concept_polygons association. vtg prod has 3, drawn in November 2021 for `Vorarlberg`,
  # `Bezirk Bludenz` and `Bezirk Bregenz` and soft-deleted three weeks later.
  #
  # The predicate is the alias' own deleted_at rather than the absence of a concept, so a polygon
  # orphaned for any other reason still reaches verify_rebuild_preconditions! and still stops the
  # deploy instead of being deleted on a guess.
  def drop_polygons_of_deleted_aliases
    rows = execute(<<~SQL.squish).cmd_tuples
      DELETE FROM classification_polygons cp
      USING classification_aliases ca
      WHERE ca.id = cp.classification_alias_id
        AND ca.deleted_at IS NOT NULL
    SQL

    say "dropped #{rows} polygons whose alias is soft-deleted"
  end

  # Soft-deleted legacy rows have nowhere to go - `concepts`, `concept_schemes` and `concept_links`
  # carry no deleted_at - so they move into the history tables the delete triggers already write to.
  # `deleted_at` is taken over explicitly, because all three history tables default it to now() and
  # would otherwise stamp the migration's own timestamp on rows deleted years ago. And a group only
  # becomes a `related` link when its alias is not the primary alias of its own classification: that
  # own pairing never produced a concept_link, and backfilling it would write a self-link
  # (parent_id = child_id) of a kind `concept_link_histories` holds none of.
  def backfill_histories
    concept_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concept_histories (
        id, internal_name, name_i18n, description_i18n, external_system_id, external_key,
        concept_scheme_id, order_a, assignable, internal, uri, ui_configs,
        created_at, updated_at, deleted_at
      )
      SELECT ca.id, ca.internal_name, COALESCE(ca.name_i18n, '{}'), COALESCE(ca.description_i18n, '{}'),
        COALESCE(ca.external_source_id, c.external_source_id),
        COALESCE(ca.external_key, c.external_key),
        ct.classification_tree_label_id,
        ca.order_a, ca.assignable, ca.internal,
        COALESCE(ca.uri, c.uri), COALESCE(ca.ui_configs, '{}'),
        ca.created_at, ca.updated_at, ca.deleted_at
      FROM classification_aliases ca
      LEFT JOIN classification_trees ct ON ct.classification_alias_id = ca.id
      LEFT JOIN LATERAL (
        SELECT cl.external_source_id, cl.external_key, cl.uri
        FROM classification_groups cg
        JOIN classifications cl ON cl.id = cg.classification_id
        WHERE cg.classification_alias_id = ca.id
        ORDER BY cg.created_at
        LIMIT 1
      ) c ON TRUE
      WHERE ca.deleted_at IS NOT NULL
      ON CONFLICT (id) DO NOTHING
    SQL

    scheme_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concept_scheme_histories (
        id, name, external_system_id, external_key, internal, visibility, change_behaviour,
        created_at, updated_at, deleted_at
      )
      SELECT ctl.id, ctl.name, ctl.external_source_id, ctl.external_key, ctl.internal,
        COALESCE(ctl.visibility, '{}'), COALESCE(ctl.change_behaviour, '{}'),
        ctl.created_at, ctl.updated_at, ctl.deleted_at
      FROM classification_tree_labels ctl
      WHERE ctl.deleted_at IS NOT NULL
      ON CONFLICT (id) DO NOTHING
    SQL

    broader_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concept_link_histories (id, parent_id, child_id, link_type, deleted_at)
      SELECT ct.id, ct.parent_classification_alias_id, ct.classification_alias_id, 'broader', ct.deleted_at
      FROM classification_trees ct
      WHERE ct.deleted_at IS NOT NULL
      ON CONFLICT (id) DO NOTHING
    SQL

    related_rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO concept_link_histories (id, parent_id, child_id, link_type, deleted_at)
      SELECT cg.id, cg.classification_alias_id, pcg.classification_alias_id, 'related', cg.deleted_at
      FROM classification_groups cg
      JOIN (
        SELECT DISTINCT ON (classification_id) classification_id, classification_alias_id
        FROM classification_groups
        ORDER BY classification_id, created_at
      ) pcg ON pcg.classification_id = cg.classification_id
      WHERE cg.deleted_at IS NOT NULL
        AND pcg.classification_alias_id <> cg.classification_alias_id
      ON CONFLICT (id) DO NOTHING
    SQL

    say "backfilled #{concept_rows} concept, #{scheme_rows} concept scheme and #{broader_rows + related_rows} concept link histories"
  end

  # build_concept_contents joins classification -> concept and carries the source row's `id`
  # through, so it needs that mapping to be one to one, and neither direction is guaranteed by
  # construction. Both are checked here for `classification_contents`, because the migration drops
  # the source tables in the same statement that reads them and there is no `down`.
  #
  # upsert_concept_tables_trigger_function computes its `primary` flag per *alias* - "this alias has
  # at most one live classification_group" - so:
  #
  # A classification that picked up a second live group projects to no concept, and the join drops
  # its content assignments without saying so. vcloud-dev has 1073 such aliases and 9 live
  # classifications with no concept, none of them referenced.
  #
  # A classification reached by two aliases that each have exactly one live group projects to two
  # concepts, and the join turns one source row into two rows sharing an `id`, which the primary key
  # then rejects. `concepts.classification_id` carries a plain non-unique index (20240325085848), so
  # nothing at the schema level forbids the pair. vcloud-dev has none among referenced
  # classifications - its rebuild created both primary keys - but the deploy would otherwise abort
  # on Postgres' own `duplicate key value` rather than on the precondition this guard exists for.
  #
  # A row naming no classification at all is neither case and is not counted: `classification_id`
  # is nullable, so `c.classification_id = cc.classification_id` matches nothing for it and it
  # would read as a lost assignment while carrying none. build_concept_contents' join drops it,
  # which is where it belongs (vtg prod has one, a `universal_classifications` row from 2020).
  #
  # `classification_content_histories` aborts on neither: a history row names the classifications
  # one content version carried, so a missing concept costs that version a line in its list -
  # `Restorable#restore_concept_contents` skips a history row with no concept anyway - and two
  # concepts is a choice build_concept_contents makes rather than a defect to stop on. vcloud-dev
  # has 16,180 rows with no concept, every one of which would otherwise block the deploy.
  #
  # The things reference is counted for a different reason: 20231123103232 added that foreign key
  # NOT VALID, so a row predating it can still be an orphan, and build_concept_contents recreates
  # the constraint in its validating form.
  #
  # Each check names itself in a `label` column rather than through a column alias: Postgres
  # truncates identifiers at 63 bytes, which cuts the two longer ones mid-word in the very message
  # an operator reads while the deploy is aborting.
  def verify_rebuild_preconditions!
    problems = select_all(<<~SQL.squish).map { |row| "#{row['label']}: #{row['row_count']}" }
      WITH fan_out AS (
        SELECT classification_id FROM concepts
        WHERE classification_id IS NOT NULL
        GROUP BY classification_id HAVING COUNT(*) > 1
      )
      SELECT label, row_count FROM (
        SELECT 'classification_contents rows whose classification projects to no concept' AS label,
          (SELECT COUNT(*) FROM classification_contents cc
            WHERE cc.classification_id IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM concepts c WHERE c.classification_id = cc.classification_id)) AS row_count
        UNION ALL
        SELECT 'classification_contents rows whose classification projects to more than one concept',
          (SELECT COUNT(*) FROM classification_contents cc
            JOIN fan_out ON fan_out.classification_id = cc.classification_id)
        UNION ALL
        SELECT 'classification_contents rows referencing a missing thing',
          (SELECT COUNT(*) FROM classification_contents cc
            WHERE cc.content_data_id IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM things t WHERE t.id = cc.content_data_id))
        UNION ALL
        SELECT 'classification_polygons rows whose alias has no concept',
          (SELECT COUNT(*) FROM classification_polygons cp
            WHERE NOT EXISTS (SELECT 1 FROM concepts c WHERE c.id = cp.classification_alias_id))
      ) checks
      WHERE row_count > 0
    SQL

    raise "the cut cannot run against this data - #{problems.join('; ')}" if problems.any?
  end

  # The CCC maintenance layer reads `classification_contents`, which build_concept_contents drops,
  # and a plpgsql function resolves the tables it names when it runs rather than when they go:
  # purge_stale_transitive_paths deletes from `classification_alias_paths_transitive` two steps
  # later, its statement-level `delete_ccc_relations_transitive_trigger` calls
  # `generate_ccc_from_ca_ids_transitive`, and the migration aborts on `relation
  # "classification_contents" does not exist`. Only a database with
  # Feature::TransitiveClassificationPath on reaches it - that feature is what leaves the trigger
  # enabled, and a disabled trigger never fires - so the cut passed everywhere it was tried.
  #
  # The five are dropped rather than disabled because create_triggers recreates all of them on
  # `concept_paths` and `concept_paths_transitive` once rename_satellite_tables has moved the
  # tables, with apply_transitive_trigger_state setting tgenabled from the feature afterwards: the
  # state the migration ends in is the same one, reached without the legacy functions running once.
  def drop_legacy_ccc_triggers
    execute <<~SQL.squish
      DROP TRIGGER IF EXISTS generate_collected_classification_content_relations_trigger ON classification_alias_paths;
      DROP TRIGGER IF EXISTS update_collected_classification_content_relations_trigger ON classification_alias_paths;
      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON classification_alias_paths_transitive;
      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON classification_alias_paths_transitive;
      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_update_trigger ON classification_alias_paths_transitive;
    SQL
  end

  # The one real value change of the whole cut: a data hash carries classification ids, while
  # `collected_classification_contents`, the filter layer and API v4 already carry concept ids, so
  # the rebuild is a join - over the mapping verify_rebuild_preconditions! has just shown to be one
  # to one, which is what lets `cc.id` carry through as the new primary key. It is a fresh table
  # rather than an UPDATE because the UPDATE would rewrite every row and leave the bloat behind, and
  # because the triggers only go on once the data is in - otherwise every row fires ccc generation.
  #
  # `concept_content_histories` carries `cch.id` the same way, but its source rows have passed no
  # such guard: the join takes one row per classification - the lowest of the concepts it projects
  # to - so a source row projecting to none is dropped and one projecting to several keeps a single
  # concept. That pick is resolved on the small side, because ordering the join output by `cch.id`
  # would sort the whole history table; both counts come off one pass over it, while it still exists.
  def build_concept_contents
    dropped, collapsed = select_rows(<<~SQL.squish).first
      WITH projection AS (
        SELECT classification_id, COUNT(*) AS concepts
        FROM concepts WHERE classification_id IS NOT NULL
        GROUP BY classification_id
      )
      SELECT COUNT(*) FILTER (WHERE p.concepts IS NULL),
        COUNT(*) FILTER (WHERE p.concepts > 1)
      FROM classification_content_histories cch
      LEFT JOIN projection p ON p.classification_id = cch.classification_id
    SQL

    execute <<~SQL.squish
      CREATE TABLE concept_contents (
        id uuid DEFAULT gen_random_uuid() NOT NULL,
        content_data_id uuid,
        concept_id uuid,
        seen_at timestamp without time zone,
        created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
        updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
        relation character varying NOT NULL
      );

      INSERT INTO concept_contents (id, content_data_id, concept_id, seen_at, created_at, updated_at, relation)
      SELECT cc.id, cc.content_data_id, c.id, cc.seen_at, cc.created_at, cc.updated_at, cc.relation
      FROM classification_contents cc
      JOIN concepts c ON c.classification_id = cc.classification_id;

      ALTER TABLE concept_contents ADD CONSTRAINT concept_contents_pkey PRIMARY KEY (id);
      CREATE INDEX index_concept_contents_on_concept_id ON concept_contents USING btree (concept_id, content_data_id);
      CREATE INDEX index_concept_contents_on_content_data_id ON concept_contents USING btree (content_data_id);
      CREATE UNIQUE INDEX index_concept_contents_on_unique_constraint ON concept_contents USING btree (content_data_id, concept_id, relation);
      ALTER TABLE concept_contents ADD CONSTRAINT fk_concept_contents_things
        FOREIGN KEY (content_data_id) REFERENCES things(id) ON DELETE CASCADE;
      ALTER TABLE concept_contents ADD CONSTRAINT fk_concept_contents_concepts
        FOREIGN KEY (concept_id) REFERENCES concepts(id) ON DELETE CASCADE;

      CREATE TABLE concept_content_histories (
        id uuid DEFAULT gen_random_uuid() NOT NULL,
        content_data_history_id uuid,
        concept_id uuid,
        seen_at timestamp without time zone,
        created_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
        updated_at timestamp without time zone DEFAULT transaction_timestamp() NOT NULL,
        relation character varying
      );

      INSERT INTO concept_content_histories (id, content_data_history_id, concept_id, seen_at, created_at, updated_at, relation)
      SELECT cch.id, cch.content_data_history_id, c.concept_id, cch.seen_at, cch.created_at, cch.updated_at, cch.relation
      FROM classification_content_histories cch
      JOIN (
        SELECT DISTINCT ON (classification_id) classification_id, id AS concept_id
        FROM concepts
        WHERE classification_id IS NOT NULL
        ORDER BY classification_id, id
      ) c ON c.classification_id = cch.classification_id;

      ALTER TABLE concept_content_histories ADD CONSTRAINT concept_content_histories_pkey PRIMARY KEY (id);
      CREATE INDEX concept_content_data_history_id_idx ON concept_content_histories USING btree (content_data_history_id);
      CREATE INDEX index_concept_content_histories_on_concept_id ON concept_content_histories USING btree (concept_id);

      DROP TABLE classification_contents;
      DROP TABLE classification_content_histories;
    SQL

    say "dropped #{dropped} content history assignments whose classification projects to no concept, kept the lowest concept for #{collapsed} projecting to several"
  end

  # `classification_user_groups` is the one satellite table keyed by a classification rather than by
  # an alias, so the `classification_id` -> `concept_id` rename in rename_satellite_tables moves the
  # column without moving the value: every pre-existing row would hold a classification id in a
  # column `UserGroup#concepts` reads as a concept id, and both that association and the
  # `user_group_classifications` user filter would resolve to nothing. Concepts inherited *alias*
  # ids (`INSERT INTO concepts(id, ...) SELECT ca.id`, 20240325103342), so the two id spaces never
  # overlap and no row survives the rename by luck. Nothing catches it later either: the table never
  # had a foreign key (20220530063350 creates a bare `t.uuid :classification_id` with an index).
  #
  # A row resolves the way develop's association chain did - `has_many :classifications, through:
  # :classification_user_groups` then `has_many :classification_aliases, through:
  # :classification_groups`, over live rows in both, since Classification and ClassificationGroup
  # are acts_as_paranoid - and every alias is a concept of the same id. That chain is one to many,
  # so a classification mapped onto two aliases becomes two rows rather than an arbitrarily chosen
  # one. It is also wider than `concepts.classification_id`, which names only the alias a
  # classification is primary for: joining over that column instead would drop the mapped aliases
  # develop resolved and displayed.
  #
  # A row that resolves to nothing is deleted rather than kept: it read as nothing on develop too,
  # and keeping it is the dangling reference this step exists to prevent.
  def remap_user_group_concepts
    execute <<~SQL.squish
      CREATE TEMP TABLE remapped_user_group_concepts ON COMMIT DROP AS
      SELECT cug.id AS source_id, cug.user_group_id, cg.classification_alias_id AS concept_id,
        cug.seen_at, cug.created_at, cug.updated_at
      FROM classification_user_groups cug
      JOIN classifications c ON c.id = cug.classification_id AND c.deleted_at IS NULL
      JOIN classification_groups cg ON cg.classification_id = c.id AND cg.deleted_at IS NULL
      JOIN concepts ON concepts.id = cg.classification_alias_id
    SQL

    dropped = select_value(<<~SQL.squish)
      SELECT COUNT(*) FROM classification_user_groups cug
      WHERE NOT EXISTS (SELECT 1 FROM remapped_user_group_concepts r WHERE r.source_id = cug.id)
    SQL

    execute 'DELETE FROM classification_user_groups'

    rows = execute(<<~SQL.squish).cmd_tuples
      INSERT INTO classification_user_groups (user_group_id, classification_id, seen_at, created_at, updated_at)
      SELECT DISTINCT ON (user_group_id, concept_id) user_group_id, concept_id, seen_at, created_at, updated_at
      FROM remapped_user_group_concepts
      ORDER BY user_group_id, concept_id, created_at
    SQL

    say "remapped the user group concepts onto #{rows} assignments, dropping #{dropped} source rows that resolved to none"
  end

  # `classification_alias_paths_transitive` caches every route through the tree, and its rows outlive
  # the aliases they name: its foreign key pointed at `classification_aliases`, which keeps
  # soft-deleted rows, so soft-deleting an alias dropped none of its paths and no recompute
  # revisited them afterwards. The projection gave those aliases no concept, so repointing that
  # foreign key at `concepts` in rename_satellite_tables is what first rejects the rows.
  #
  # verify_rebuild_preconditions! aborts on this same condition in `classification_polygons`, which
  # is authored data. A path is derived, and `concept_links` carries no edge to a deleted alias, so
  # `upsert_concept_paths_transitive` recomputes every route that is still real and can reproduce
  # none of these. That is also why the predicate is `full_path_ids` and not the foreign key's own
  # column: a route *through* a deleted alias is as unreachable as one ending at it, and its
  # `ancestor_ids` and `mapped_ids` name concepts that no longer exist. On nlw prod that is 27,117
  # of 48,071 rows - the 16,018 the foreign key itself would catch, plus the rest of the 147 deleted
  # aliases' subtrees - and every concept still in the tree keeps at least one path.
  def purge_stale_transitive_paths
    rows = execute(<<~SQL.squish).cmd_tuples
      DELETE FROM classification_alias_paths_transitive capt
      WHERE EXISTS (
        SELECT 1 FROM unnest(capt.full_path_ids) AS path_id
        WHERE NOT EXISTS (SELECT 1 FROM concepts c WHERE c.id = path_id)
      )
    SQL

    say "dropped #{rows} transitive path rows routing through an alias the projection gave no concept"
  end

  # `collected_classification_contents` denormalizes the concepts a thing carries, and its rows
  # outlive the aliases and tree labels they name for the reason purge_stale_transitive_paths gives:
  # `fk_classification_aliases` and `fk_classification_tree_labels` cascade from
  # `classification_aliases` and `classification_tree_labels`, which keep soft-deleted rows, so
  # soft-deleting either dropped none of the collected rows naming it. The projection gives those no
  # concept and no concept scheme, so repointing both foreign keys in rename_satellite_tables is what
  # first rejects the rows - rlp's dev dump aborts the migration on 9,840 of them, left by two
  # aliases soft-deleted while 4,920 things still carried them.
  #
  # A collected row is derived, like a transitive path and unlike the authored
  # `classification_polygons` verify_rebuild_preconditions! rightly raises on:
  # `generate_collected_classification_content_relations` rebuilds it from a thing's assignments, as
  # db/data_migrate/20250108090922_fix_ccc_again.rb does for the whole table. A deleted alias
  # contributes no assignment, so that rebuild reproduces none of these rows and the step deletes them.
  #
  # Both columns are checked, because rename_satellite_tables adds a foreign key for each and a
  # soft-deleted tree label strands its rows exactly as a soft-deleted alias does.
  def purge_stale_collected_contents
    rows = execute(<<~SQL.squish).cmd_tuples
      DELETE FROM collected_classification_contents ccc
      WHERE NOT EXISTS (SELECT 1 FROM concepts c WHERE c.id = ccc.classification_alias_id)
        OR NOT EXISTS (SELECT 1 FROM concept_schemes cs WHERE cs.id = ccc.classification_tree_label_id)
    SQL

    say "dropped #{rows} collected content rows naming an alias or tree label the projection gave no concept"
  end

  # `delete_concepts_to_histories_trigger_function` builds its INSERT column list at runtime from
  # information_schema over `concept_histories` and selects `oc.<column>` out of `old_concepts`, so
  # dropping `concepts.classification_id` without `concept_histories.classification_id` makes the
  # next concept delete raise `column oc.classification_id does not exist`. Both go together.
  def drop_projection_columns
    remove_foreign_key :concepts, :classification_aliases, column: :id, if_exists: true
    remove_foreign_key :concept_schemes, :classification_tree_labels, column: :id, if_exists: true

    remove_column :concepts, :classification_id, if_exists: true
    remove_column :concept_histories, :classification_id, if_exists: true

    # concept_schemes mirrored classification_tree_labels and never needed the default; now that a
    # scheme is created directly, a new one without it stops answering ConceptScheme#trigger_webhooks?
    change_column_default :concept_schemes, :change_behaviour, from: [], to: ['trigger_webhooks']
  end

  # `concepts` inherited this index from the days when it was a trigger-maintained projection of
  # `classification_aliases`: uniqueness was enforced on the source table, so covering only the rows
  # that carry an external system was enough here. Now that `concepts` is the authoritative table it
  # has to carry what `classification_aliases` carried - `NULLS NOT DISTINCT` over every keyed row:
  #
  #   index_classification_aliases_unique_external_source_id_and_key
  #     UNIQUE (external_source_id, external_key) NULLS NOT DISTINCT
  #     WHERE deleted_at IS NULL AND external_key IS NOT NULL
  #
  # A concept defined in a classifications.yml has no external system, so under the narrow index it
  # matches no ON CONFLICT target and ConceptScheme#insert_all_external_concepts appends a second
  # copy of it on every `dc:update` - 688 of them on the first run against vcloud-dev.
  def widen_external_key_index
    execute <<~SQL.squish
      DROP INDEX IF EXISTS index_concepts_on_external_system_id_and_external_key;
      CREATE UNIQUE INDEX index_concepts_on_external_system_id_and_external_key
        ON concepts USING btree (external_system_id, external_key) NULLS NOT DISTINCT
        WHERE external_key IS NOT NULL;
    SQL
  end

  def rename_satellite_tables
    RENAMED_TABLES.each { |old, new| rename_table old, new }

    rename_column :collected_concept_contents, :classification_alias_id, :concept_id
    rename_column :collected_concept_contents, :classification_tree_label_id, :concept_scheme_id
    rename_column :concept_paths_transitive, :classification_alias_id, :concept_id
    rename_column :concept_polygons, :classification_alias_id, :concept_id
    rename_column :concept_user_groups, :classification_id, :concept_id

    RENAMED_INDEXES.each { |old, new| execute "ALTER INDEX IF EXISTS #{old} RENAME TO #{new}" }
    rename_not_null_constraints

    # All three pointed at a legacy table. The ids on both sides are the same rows, so repointing
    # them validates without a single value changing.
    remove_foreign_key :collected_concept_contents, column: :concept_id
    remove_foreign_key :collected_concept_contents, column: :concept_scheme_id
    remove_foreign_key :concept_paths_transitive, column: :concept_id
    execute 'ALTER TABLE concept_paths RENAME CONSTRAINT fk_cap_concepts TO fk_concept_paths_concepts'

    add_foreign_key :collected_concept_contents, :concepts, column: :concept_id, on_delete: :cascade
    add_foreign_key :collected_concept_contents, :concept_schemes, column: :concept_scheme_id, on_delete: :cascade
    add_foreign_key :concept_paths_transitive, :concepts, column: :concept_id, on_delete: :cascade

    # These two had no foreign key at all as classification tables, which is why a classification_id
    # could sit in a column now read as a concept_id and remap_user_group_concepts had to go find it.
    # Every other concept satellite carries one, and Concept::History already documents this cascade
    # as the reason a deleted concept has an empty concept_polygons association.
    #
    # Both are validated on creation: remap_user_group_concepts has just rewritten every
    # concept_user_groups row to an id it joined against concepts, and
    # verify_rebuild_preconditions! aborts the deploy on a polygon whose alias has no concept - the
    # rows a soft-deleted classification_alias would leave behind, since the projection gave those
    # no concept (0 of vcloud-dev's 17,204 polygons).
    add_foreign_key :concept_polygons, :concepts, column: :concept_id, on_delete: :cascade
    add_foreign_key :concept_user_groups, :concepts, column: :concept_id, on_delete: :cascade
  end

  # A table rename leaves its constraint names behind, so `collected_concept_contents` would keep a
  # `collected_classification_conte_classification_alias_id_not_null` on its concept_id. Postgres
  # names these `<table>_<column>_not_null` itself, so they are recomputed rather than substituted -
  # the legacy names are truncated to 63 characters and no substitution restores them.
  def rename_not_null_constraints
    select_rows(<<~SQL.squish).each do |table, constraint, column|
      SELECT c.relname, con.conname, a.attname
      FROM pg_constraint con
      JOIN pg_class c ON c.oid = con.conrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = con.conkey[1]
      WHERE n.nspname = 'public'
        AND con.contype = 'n'
        AND con.conname LIKE '%classification%'
        AND c.relname IN (#{RENAMED_TABLES.values.map { |t| connection.quote(t) }.join(', ')})
    SQL
      execute "ALTER TABLE #{table} RENAME CONSTRAINT #{connection.quote_column_name(constraint)} TO #{connection.quote_column_name("#{table}_#{column}_not_null")}"
    end
  end

  # The search index denormalizes the assigned concepts into these three columns and has held
  # concept ids in both arrays all along. `search_vector` is a generated column over
  # classification_string, and its stored expression references the column by attnum, so the rename
  # carries it along instead of forcing a rebuild of the table.
  def rename_search_columns
    rename_column :searches, :classification_string, :concept_string
    rename_column :searches, :classification_aliases_mapping, :concepts_mapping
    rename_column :searches, :classification_ancestors_mapping, :concept_ancestors_mapping
  end

  # `primary_classification_groups` exists only to find the primary alias of a classification, a
  # hop that has no counterpart left. Dropping the tables takes their triggers with them.
  def drop_legacy_tables
    execute 'DROP VIEW IF EXISTS primary_classification_groups'
    LEGACY_TABLES.each { |table| drop_table table, if_exists: true }
  end

  def create_triggers
    execute <<~SQL.squish
      CREATE TRIGGER generate_collected_concept_content_relations_trigger_1 AFTER INSERT ON concept_contents
        FOR EACH ROW EXECUTE FUNCTION generate_collected_concept_content_relations_trigger_1();
      CREATE TRIGGER generate_collected_concept_content_relations_trigger_2 AFTER DELETE ON concept_contents
        FOR EACH ROW EXECUTE FUNCTION generate_collected_concept_content_relations_trigger_2();
      CREATE TRIGGER update_collected_concept_content_relations_trigger_1
        AFTER UPDATE OF content_data_id, concept_id, relation ON concept_contents
        FOR EACH ROW WHEN (
          old.content_data_id IS DISTINCT FROM new.content_data_id
          OR old.concept_id IS DISTINCT FROM new.concept_id
          OR old.relation::text IS DISTINCT FROM new.relation::text
        ) EXECUTE FUNCTION generate_collected_concept_content_relations_trigger_1();
      CREATE TRIGGER generate_ccc_relations_transitive_trigger AFTER INSERT ON concept_contents
        FOR EACH ROW EXECUTE FUNCTION generate_ccc_relations_transitive_trigger_2();
      CREATE TRIGGER delete_ccc_relations_transitive_trigger AFTER DELETE ON concept_contents
        FOR EACH ROW EXECUTE FUNCTION delete_ccc_relations_transitive_trigger_1();
      CREATE TRIGGER update_ccc_relations_transitive_trigger
        AFTER UPDATE OF content_data_id, concept_id, relation ON concept_contents
        FOR EACH ROW WHEN (
          old.content_data_id IS DISTINCT FROM new.content_data_id
          OR old.concept_id IS DISTINCT FROM new.concept_id
          OR old.relation::text IS DISTINCT FROM new.relation::text
        ) EXECUTE FUNCTION generate_ccc_relations_transitive_trigger_2();

      DROP TRIGGER IF EXISTS generate_collected_classification_content_relations_trigger ON concept_paths;
      DROP TRIGGER IF EXISTS update_collected_classification_content_relations_trigger ON concept_paths;
      CREATE TRIGGER generate_collected_concept_content_relations_trigger AFTER INSERT ON concept_paths
        REFERENCING NEW TABLE AS new_concept_paths
        FOR EACH STATEMENT EXECUTE FUNCTION generate_collected_concept_content_relations_trigger_5();
      CREATE TRIGGER update_collected_concept_content_relations_trigger AFTER UPDATE ON concept_paths
        FOR EACH ROW EXECUTE FUNCTION generate_collected_concept_content_relations_trigger_3();

      DROP TRIGGER IF EXISTS delete_ccc_relations_transitive_trigger ON concept_paths_transitive;
      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_trigger ON concept_paths_transitive;
      DROP TRIGGER IF EXISTS generate_ccc_relations_transitive_update_trigger ON concept_paths_transitive;
      CREATE TRIGGER delete_ccc_relations_transitive_trigger AFTER DELETE ON concept_paths_transitive
        REFERENCING OLD TABLE AS old_concept_paths_transitive
        FOR EACH STATEMENT EXECUTE FUNCTION delete_ccc_relations_transitive_trigger_2();
      CREATE TRIGGER generate_ccc_relations_transitive_trigger AFTER INSERT ON concept_paths_transitive
        REFERENCING NEW TABLE AS new_concept_paths_transitive
        FOR EACH STATEMENT EXECUTE FUNCTION generate_ccc_relations_transitive_trigger_1();
      CREATE TRIGGER generate_ccc_relations_transitive_update_trigger AFTER UPDATE ON concept_paths_transitive
        REFERENCING OLD TABLE AS old_concept_paths_transitive NEW TABLE AS new_concept_paths_transitive
        FOR EACH STATEMENT EXECUTE FUNCTION generate_ccc_relations_transitive_update_trigger_function();

      CREATE TRIGGER concepts_propagate_scheme_trigger AFTER UPDATE ON concepts
        REFERENCING OLD TABLE AS old_concepts NEW TABLE AS new_concepts
        FOR EACH STATEMENT EXECUTE FUNCTION concepts_propagate_scheme_trigger_function();
      CREATE TRIGGER update_concepts_order_a_trigger AFTER UPDATE ON concepts
        REFERENCING OLD TABLE AS old_concepts NEW TABLE AS new_concepts
        FOR EACH STATEMENT EXECUTE FUNCTION update_concepts_order_a_trigger();
      CREATE TRIGGER insert_concept_links_order_a_trigger AFTER INSERT ON concept_links
        REFERENCING NEW TABLE AS new_concept_links
        FOR EACH STATEMENT EXECUTE FUNCTION insert_concept_links_order_a_trigger();
      CREATE TRIGGER update_concept_links_order_a_trigger AFTER UPDATE ON concept_links
        REFERENCING OLD TABLE AS old_concept_links NEW TABLE AS new_concept_links
        FOR EACH STATEMENT EXECUTE FUNCTION update_concept_links_order_a_trigger();
    SQL
  end

  # Postgres creates every trigger enabled, and `create_triggers` creates concept_contents' three
  # transitive triggers and recreates concept_paths_transitive's - while `concepts`, `concept_links`
  # and `concept_schemes` keep the DISABLE that 20250424140212 left on them, the last of those
  # because replacing a trigger's function leaves tgenabled alone. With
  # Feature::TransitiveClassificationPath off the six created ones would contradict the seven, and
  # nothing later corrects it: only db/seeds.rb and data migrations every database has already
  # recorded call update_triggers, and `dc:update` runs no seed step. The `false` is update_jobs -
  # the cut leaves no mapping for RebuildClassificationMappingsJob.
  def apply_transitive_trigger_state
    DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
  end

  def drop_obsolete_functions
    (PROJECTION_FUNCTIONS + RENAMED_FUNCTIONS).each do |name|
      execute "DROP FUNCTION IF EXISTS public.#{name}"
    end
  end

  # CacheInvalidationJob and CacheInvalidationDestroyJob persist the model class as a string and
  # constantize it on perform, so every job still queued at deploy time would raise NameError.
  # `self.class.name` is the only writer, and only these two classes ever reach it.
  #
  # The WHERE names both spellings rather than the shared `DataCycleCore::Classification` prefix:
  # ActiveJob puts `job_class` in the payload, so a queued ClassificationMappingJob - a name the cut
  # keeps - would be selected by the prefix and counted as rewritten while the REPLACE leaves it
  # untouched.
  def rewrite_job_arguments
    rewritten = execute(<<~SQL.squish).cmd_tuples
      UPDATE solid_queue_jobs
      SET arguments = REPLACE(
            REPLACE(arguments, 'DataCycleCore::ClassificationTreeLabel', 'DataCycleCore::ConceptScheme'),
            'DataCycleCore::ClassificationAlias', 'DataCycleCore::Concept')
      WHERE arguments LIKE '%DataCycleCore::ClassificationTreeLabel%'
        OR arguments LIKE '%DataCycleCore::ClassificationAlias%'
    SQL

    say "rewrote #{rewritten} queued job payload(s)" if rewritten.positive?

    rewrite_delayed_job_handlers
  end

  # db/data_migrate/20260417160449_migrate_delayed_jobs_to_solid_queue moves what still waits in
  # delayed_jobs over by deserializing and re-enqueuing it, and dc:update runs every schema migration
  # before the first data migration. So on a deployment where that upgrade is still pending, payloads
  # reach solid_queue_jobs after the rewrite above has already run, and the class name they carry is
  # a plain String rather than a GlobalID - nothing rejects it on the way in, and
  # CacheInvalidationJob raises NameError when it constantizes it.
  #
  # handler is YAML, which carries no length prefix, so replacing a class name with a shorter one
  # leaves the document parseable.
  def rewrite_delayed_job_handlers
    return unless table_exists?(:delayed_jobs)

    rewritten = execute(<<~SQL.squish).cmd_tuples
      UPDATE delayed_jobs
      SET handler = REPLACE(
            REPLACE(handler, 'DataCycleCore::ClassificationTreeLabel', 'DataCycleCore::ConceptScheme'),
            'DataCycleCore::ClassificationAlias', 'DataCycleCore::Concept')
      WHERE handler LIKE '%DataCycleCore::ClassificationTreeLabel%'
        OR handler LIKE '%DataCycleCore::ClassificationAlias%'
    SQL

    say "rewrote #{rewritten} waiting delayed_job payload(s)" if rewritten.positive?
  end

  def replace_trigger_functions
    execute concept_path_functions
    execute ccc_functions
    execute ccc_trigger_functions
    execute history_functions
    execute order_a_functions
    execute scheme_propagation_function
  end

  # Replaces update_classification_tree_tree_label_id_trigger. The scheme used to sit on the
  # classification_trees row of every concept in a subtree, and that trigger rewrote all of them
  # whenever one moved; concepts.concept_scheme_id is the same per-concept column and needs the same
  # rewrite. Nothing else re-derives it: upsert_concept_paths reads the *root's* scheme, but
  # generate_collected_concept_content_relations reads `c2.concept_scheme_id` per concept, so a
  # descendant left behind would classify its contents under the scheme it came from.
  #
  # A concept keeps a scheme the statement assigned it explicitly, and everything below it inherits
  # from its nearest such ancestor. `concept_paths.ancestor_ids` runs nearest first (measured: the
  # path of "CC BY 4.0" holds {"CC BY", "Creative Commons", "Open Data"} and stops short of the
  # scheme), so ARRAY_POSITION ASC picks that ancestor, and one statement reaches every descendant at
  # any depth. Two conditions the shape is not obvious about:
  #
  # - The NOT EXISTS is what makes "explicitly" hold. Moving a concept and one of its own descendants
  #   to different schemes in a single UPDATE otherwise resolves the descendant as just another row
  #   under the outer concept, so it loses the scheme it was handed and drags its subtree along.
  # - A statement-level trigger fires even when its UPDATE matched no row, so an unconditional UPDATE
  #   fires this trigger again on an empty transition table, and again: PG::StatementTooComplex
  #   ("stack depth limit exceeded"), measured on a move with 12544 descendants. Testing the
  #   transition tables alone would not stop it either, because on the second pass they hold the
  #   descendants just rewritten and their scheme really did change - so the IF asks whether any
  #   descendant still disagrees. update_concepts_order_a guards in the same place.
  def scheme_propagation_function
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.concepts_propagate_scheme_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
        IF EXISTS (
          SELECT 1
          FROM new_concepts nc
          JOIN old_concepts oc ON oc.id = nc.id
          JOIN concept_paths cp ON cp.ancestor_ids @> ARRAY [nc.id]::uuid[]
          JOIN concepts d ON d.id = cp.id
          WHERE oc.concept_scheme_id IS DISTINCT FROM nc.concept_scheme_id
            AND d.concept_scheme_id IS DISTINCT FROM nc.concept_scheme_id
            AND NOT EXISTS (SELECT 1 FROM new_concepts own WHERE own.id = cp.id)
        ) THEN
          UPDATE concepts
          SET concept_scheme_id = moved.concept_scheme_id
          FROM (
            SELECT DISTINCT ON (cp.id) cp.id, nc.concept_scheme_id
            FROM new_concepts nc
            JOIN old_concepts oc ON oc.id = nc.id
            JOIN concept_paths cp ON cp.ancestor_ids @> ARRAY [nc.id]::uuid[]
            WHERE oc.concept_scheme_id IS DISTINCT FROM nc.concept_scheme_id
              AND NOT EXISTS (SELECT 1 FROM new_concepts own WHERE own.id = cp.id)
            ORDER BY cp.id, ARRAY_POSITION(cp.ancestor_ids, nc.id) ASC
          ) moved
          WHERE moved.id = concepts.id
            AND concepts.concept_scheme_id IS DISTINCT FROM moved.concept_scheme_id;
        END IF;
        RETURN NULL;
      END; $function$;
    SQL
  end

  # The path maintenance was already driven off `concepts`, `concept_links` and `concept_schemes`;
  # only the two functions it delegates to changed their name.
  def concept_path_functions
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.concept_links_create_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths (ARRAY_AGG(new_concept_links.child_id))
      FROM new_concept_links
      WHERE new_concept_links.link_type = 'broader';
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concept_links_create_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths_transitive (ARRAY_AGG(new_concept_links.child_id))
      FROM new_concept_links;
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concept_links_delete_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths_transitive (ARRAY_AGG(old_concept_links.child_id))
      FROM old_concept_links;
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concept_links_update_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths (ARRAY_AGG(updated_concept_links.child_id))
        FROM (
        SELECT DISTINCT new_concept_links.child_id
        FROM old_concept_links
        JOIN new_concept_links ON old_concept_links.id = new_concept_links.id
        WHERE new_concept_links.link_type = 'broader'
        AND old_concept_links.parent_id IS DISTINCT
        FROM new_concept_links.parent_id
        OR old_concept_links.child_id IS DISTINCT
      FROM new_concept_links.child_id ) "updated_concept_links";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concept_links_update_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths_transitive (ARRAY_AGG(updated_concept_links.child_id))
        FROM (
        SELECT DISTINCT new_concept_links.child_id
        FROM old_concept_links
        JOIN new_concept_links ON old_concept_links.id = new_concept_links.id
        WHERE old_concept_links.child_id IS DISTINCT
        FROM new_concept_links.child_id
        OR old_concept_links.parent_id IS DISTINCT
        FROM new_concept_links.parent_id
        OR old_concept_links.link_type IS DISTINCT
      FROM new_concept_links.link_type ) "updated_concept_links";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concept_schemes_update_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths (ARRAY_AGG(updated_concepts.id))
        FROM (
        SELECT DISTINCT concepts.id
        FROM old_concept_schemes
        JOIN new_concept_schemes ON old_concept_schemes.id = new_concept_schemes.id
        JOIN concepts ON concepts.concept_scheme_id = new_concept_schemes.id
        WHERE old_concept_schemes.name IS DISTINCT
      FROM new_concept_schemes.name ) "updated_concepts";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concept_schemes_update_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths_transitive (ARRAY_AGG(updated_concepts.id))
        FROM (
        SELECT DISTINCT concepts.id
        FROM old_concept_schemes
        JOIN new_concept_schemes ON old_concept_schemes.id = new_concept_schemes.id
        JOIN concepts ON concepts.concept_scheme_id = new_concept_schemes.id
        WHERE old_concept_schemes.name IS DISTINCT
      FROM new_concept_schemes.name ) "updated_concepts";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concepts_create_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths (ARRAY_AGG(new_concepts.id))
      FROM new_concepts;
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concepts_create_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths_transitive (ARRAY_AGG(new_concepts.id))
      FROM new_concepts;
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concepts_delete_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths_transitive (ARRAY_AGG(old_concepts.id))
      FROM old_concepts;
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concepts_update_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths (ARRAY_AGG(updated_concepts.id))
        FROM (
        SELECT DISTINCT new_concepts.id
        FROM old_concepts
        JOIN new_concepts ON old_concepts.id = new_concepts.id
        WHERE old_concepts.internal_name IS DISTINCT
        FROM new_concepts.internal_name
        OR old_concepts.concept_scheme_id IS DISTINCT
      FROM new_concepts.concept_scheme_id ) "updated_concepts";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.concepts_update_transitive_paths_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM upsert_concept_paths_transitive (ARRAY_AGG(updated_concepts.id))
        FROM (
        SELECT DISTINCT new_concepts.id
        FROM old_concepts
        JOIN new_concepts ON old_concepts.id = new_concepts.id
        WHERE old_concepts.internal_name IS DISTINCT
        FROM new_concepts.internal_name
        OR old_concepts.concept_scheme_id IS DISTINCT
      FROM new_concepts.concept_scheme_id ) "updated_concepts";
      RETURN NULL;
      END; $function$;
    SQL
  end

  # The hop these all shared - from a classification to its primary alias - collapses: a
  # `concept_contents.concept_id` is the concept, so `JOIN concepts ON concepts.classification_id =
  # classification_contents.classification_id` has nothing left to resolve. The second argument of
  # the ccc generator goes with it; it named classifications and no statement in the body read it.
  def ccc_functions
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.generate_collected_concept_content_relations(content_ids uuid[]) RETURNS void LANGUAGE plpgsql AS $function$
      BEGIN
      IF array_length(content_ids, 1) > 0 THEN
        WITH direct_concept_content_relations AS (
          SELECT DISTINCT ON ( concept_contents.content_data_id, concept_contents.relation, c2.id ) concept_contents.content_data_id "thing_id", c2.id "concept_id", c2.concept_scheme_id "concept_scheme_id", FALSE "hidden", concept_contents.relation, ROW_NUMBER() over ( PARTITION by concept_contents.content_data_id, concept_contents.concept_id, c2.concept_scheme_id
        ORDER BY ARRAY_REVERSE(cp.full_path_ids) DESC ) AS "row_number"
        FROM concept_contents
        JOIN concept_paths ON concept_paths.id = concept_contents.concept_id
        JOIN concepts c2 ON c2.id = ANY (concept_paths.full_path_ids)
        JOIN concept_paths cp ON cp.id = c2.id
        WHERE concept_contents.content_data_id = ANY (content_ids)
        ORDER BY concept_contents.content_data_id, concept_contents.relation, c2.id, "row_number" ), related_concept_content_relations AS (
          SELECT DISTINCT ON ( concept_contents.content_data_id, concept_contents.relation, c2.id ) concept_contents.content_data_id "thing_id", c2.id "concept_id", c2.concept_scheme_id "concept_scheme_id", COALESCE(cs2.hidden_mappings, FALSE) "hidden", concept_contents.relation, ROW_NUMBER() over ( PARTITION by concept_contents.content_data_id, concept_links.parent_id, c2.concept_scheme_id
        ORDER BY ARRAY_REVERSE(cp.full_path_ids) DESC ) AS "row_number"
        FROM concept_contents
        JOIN concept_links ON concept_links.child_id = concept_contents.concept_id
        AND concept_links.link_type = 'related'
        JOIN concept_paths ON concept_links.parent_id = concept_paths.id
        JOIN concepts c2 ON c2.id = ANY (concept_paths.full_path_ids)
        LEFT OUTER JOIN concept_schemes cs2 ON cs2.id = c2.concept_scheme_id
        JOIN concept_paths cp ON cp.id = c2.id
        WHERE concept_contents.content_data_id = ANY (content_ids)
        ORDER BY concept_contents.content_data_id, concept_contents.relation, c2.id, "row_number" ), full_concept_content_relations AS (
        SELECT *, CASE WHEN direct_concept_content_relations.row_number > 1 THEN 'broader' ELSE 'direct' END AS "link_type"
        FROM direct_concept_content_relations
        UNION
        SELECT *, CASE WHEN related_concept_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type"
        FROM related_concept_content_relations ), new_collected_concept_contents AS (
        SELECT DISTINCT ON ( full_concept_content_relations.thing_id, full_concept_content_relations.relation, full_concept_content_relations.concept_id ) full_concept_content_relations.thing_id, full_concept_content_relations.concept_id, full_concept_content_relations.concept_scheme_id, full_concept_content_relations.relation, full_concept_content_relations.link_type, full_concept_content_relations.hidden
        FROM full_concept_content_relations
        ORDER BY full_concept_content_relations.thing_id, full_concept_content_relations.relation, full_concept_content_relations.concept_id, full_concept_content_relations.hidden ASC ), deleted_collected_concept_contents AS (
        DELETE FROM collected_concept_contents
        WHERE collected_concept_contents.thing_id = ANY(content_ids)
          AND NOT EXISTS (
          SELECT 1
          FROM new_collected_concept_contents
          WHERE new_collected_concept_contents.thing_id = collected_concept_contents.thing_id
          AND new_collected_concept_contents.relation = collected_concept_contents.relation
      AND new_collected_concept_contents.concept_id = collected_concept_contents.concept_id ) )
      INSERT INTO collected_concept_contents ( thing_id, concept_id, concept_scheme_id, link_type, hidden, relation )
      SELECT new_collected_concept_contents.thing_id, new_collected_concept_contents.concept_id, new_collected_concept_contents.concept_scheme_id, new_collected_concept_contents.link_type, new_collected_concept_contents.hidden, new_collected_concept_contents.relation
      FROM new_collected_concept_contents
      ON CONFLICT (thing_id, relation, concept_id)
      DO UPDATE
      SET concept_scheme_id = EXCLUDED.concept_scheme_id, link_type = EXCLUDED.link_type, hidden = EXCLUDED.hidden
      WHERE collected_concept_contents.concept_scheme_id IS DISTINCT
      FROM EXCLUDED.concept_scheme_id
      OR collected_concept_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type
      OR collected_concept_contents.hidden IS DISTINCT
      FROM EXCLUDED.hidden;
      END IF;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_collected_concept_content_relations_transitive(thing_ids uuid[]) RETURNS void LANGUAGE plpgsql AS $function$
      BEGIN
      IF array_length(thing_ids, 1) > 0 THEN
        WITH full_concept_content_relations AS (
        SELECT DISTINCT ON ( concept_contents.content_data_id, concept_contents.relation, c2.id ) concept_contents.content_data_id "thing_id", c2.id "concept_id", c2.concept_scheme_id "concept_scheme_id", concept_contents.concept_id = c2.id "direct", c2.id = ANY (concept_paths_transitive.mapped_ids)
          AND COALESCE(cs2.hidden_mappings, FALSE) "hidden", concept_contents.relation, ROW_NUMBER() over ( PARTITION by concept_contents.content_data_id, concept_paths_transitive.id, c2.concept_scheme_id
        ORDER BY ARRAY_REVERSE(cp.full_path_ids) DESC ) AS "row_number"
        FROM concept_contents
        JOIN concept_paths_transitive ON concept_paths_transitive.concept_id = concept_contents.concept_id
        JOIN concepts c2 ON c2.id = ANY ( concept_paths_transitive.full_path_ids )
        LEFT OUTER JOIN concept_schemes cs2 ON cs2.id = c2.concept_scheme_id
        JOIN concept_paths cp ON cp.id = c2.id
        WHERE concept_contents.content_data_id = ANY (thing_ids)
        ORDER BY concept_contents.content_data_id, concept_contents.relation, c2.id, "direct" DESC, "hidden" ASC, "row_number" ), new_collected_concept_contents AS (
        SELECT full_concept_content_relations.thing_id, full_concept_content_relations.concept_id, full_concept_content_relations.concept_scheme_id, CASE WHEN full_concept_content_relations.direct THEN 'direct' WHEN full_concept_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type", full_concept_content_relations.hidden, full_concept_content_relations.relation
        FROM full_concept_content_relations ), deleted_collected_concept_contents AS (
        DELETE FROM collected_concept_contents
        WHERE collected_concept_contents.thing_id = ANY(thing_ids)
          AND NOT EXISTS (
          SELECT 1
          FROM new_collected_concept_contents
          WHERE new_collected_concept_contents.thing_id = collected_concept_contents.thing_id
          AND new_collected_concept_contents.relation = collected_concept_contents.relation
      AND new_collected_concept_contents.concept_id = collected_concept_contents.concept_id ) )
      INSERT INTO collected_concept_contents ( thing_id, concept_id, concept_scheme_id, link_type, hidden, relation )
      SELECT new_collected_concept_contents.thing_id, new_collected_concept_contents.concept_id, new_collected_concept_contents.concept_scheme_id, new_collected_concept_contents.link_type, new_collected_concept_contents.hidden, new_collected_concept_contents.relation
      FROM new_collected_concept_contents
      ON CONFLICT (thing_id, relation, concept_id)
      DO UPDATE
      SET concept_scheme_id = EXCLUDED.concept_scheme_id, link_type = EXCLUDED.link_type, hidden = EXCLUDED.hidden
      WHERE collected_concept_contents.concept_scheme_id IS DISTINCT
      FROM EXCLUDED.concept_scheme_id
      OR collected_concept_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type
      OR collected_concept_contents.hidden IS DISTINCT
      FROM EXCLUDED.hidden;
      END IF;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_from_concept_ids_transitive(concept_ids uuid[]) RETURNS void LANGUAGE plpgsql AS $function$
      BEGIN
      IF array_length(concept_ids, 1) > 0 THEN
        WITH full_concept_content_relations AS (
        SELECT DISTINCT ON ( concept_contents.content_data_id, concept_contents.relation, c2.id ) concept_contents.content_data_id "thing_id", c2.id "concept_id", c2.concept_scheme_id "concept_scheme_id", concept_contents.concept_id = c2.id "direct", c2.id = ANY (concept_paths_transitive.mapped_ids)
          AND COALESCE(cs2.hidden_mappings, FALSE) "hidden", concept_contents.relation, ROW_NUMBER() over ( PARTITION by concept_contents.content_data_id, concept_paths_transitive.id, c2.concept_scheme_id
        ORDER BY ARRAY_REVERSE(cp.full_path_ids) DESC ) AS "row_number"
        FROM concept_contents
        JOIN concept_paths_transitive ON concept_paths_transitive.concept_id = concept_contents.concept_id
        JOIN concepts c2 ON c2.id = ANY ( concept_paths_transitive.full_path_ids )
        LEFT OUTER JOIN concept_schemes cs2 ON cs2.id = c2.concept_scheme_id
        JOIN concept_paths cp ON cp.id = c2.id
        WHERE cp.full_path_ids && concept_ids
        ORDER BY concept_contents.content_data_id, concept_contents.relation, c2.id, "direct" DESC, "hidden" ASC, "row_number" ), new_collected_concept_contents AS (
        SELECT full_concept_content_relations.thing_id, full_concept_content_relations.concept_id, full_concept_content_relations.concept_scheme_id, CASE WHEN full_concept_content_relations.direct THEN 'direct' WHEN full_concept_content_relations.row_number > 1 THEN 'broader' ELSE 'related' END AS "link_type", full_concept_content_relations.hidden, full_concept_content_relations.relation
        FROM full_concept_content_relations
        WHERE full_concept_content_relations.concept_id = ANY(concept_ids) ), deleted_collected_concept_contents AS (
        DELETE FROM collected_concept_contents
        WHERE collected_concept_contents.concept_id = ANY(concept_ids)
          AND NOT EXISTS (
          SELECT 1
          FROM new_collected_concept_contents
          WHERE new_collected_concept_contents.thing_id = collected_concept_contents.thing_id
          AND new_collected_concept_contents.relation = collected_concept_contents.relation
      AND new_collected_concept_contents.concept_id = collected_concept_contents.concept_id ) )
      INSERT INTO collected_concept_contents ( thing_id, concept_id, concept_scheme_id, link_type, hidden, relation )
      SELECT new_collected_concept_contents.thing_id, new_collected_concept_contents.concept_id, new_collected_concept_contents.concept_scheme_id, new_collected_concept_contents.link_type, new_collected_concept_contents.hidden, new_collected_concept_contents.relation
      FROM new_collected_concept_contents
      ON CONFLICT (thing_id, relation, concept_id)
      DO UPDATE
      SET concept_scheme_id = EXCLUDED.concept_scheme_id, link_type = EXCLUDED.link_type, hidden = EXCLUDED.hidden
      WHERE collected_concept_contents.concept_scheme_id IS DISTINCT
      FROM EXCLUDED.concept_scheme_id
      OR collected_concept_contents.link_type IS DISTINCT
      FROM EXCLUDED.link_type
      OR collected_concept_contents.hidden IS DISTINCT
      FROM EXCLUDED.hidden;
      END IF;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.upsert_concept_paths(concept_ids uuid[]) RETURNS void LANGUAGE plpgsql AS $function$
      BEGIN
      IF array_length(concept_ids, 1) > 0 THEN
        WITH RECURSIVE paths( id, parent_id, ancestor_ids, full_path_ids, full_path_names, tree_label_id ) AS (
        SELECT c.id, cl.parent_id, ARRAY []::uuid [], ARRAY [c.id], ARRAY [c.internal_name], c.concept_scheme_id
        FROM concepts c
        JOIN concept_links cl ON cl.child_id = c.id
        AND cl.link_type = 'broader'
        WHERE c.id = ANY(concept_ids)
        UNION ALL
        SELECT paths.id, cl.parent_id, ancestor_ids || c.id, full_path_ids || c.id, full_path_names || c.internal_name, c.concept_scheme_id
        FROM concepts c
        JOIN paths ON paths.parent_id = c.id
        JOIN concept_links cl ON cl.child_id = c.id
        AND cl.link_type = 'broader'
        WHERE c.id <> ALL (paths.full_path_ids) ), child_paths( id, ancestor_ids, full_path_ids, full_path_names ) AS (
        SELECT paths.id AS id, paths.ancestor_ids AS ancestor_ids, paths.full_path_ids AS full_path_ids, paths.full_path_names || cs.name AS full_path_names
        FROM paths
        JOIN concept_schemes cs ON cs.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT c.id AS id, (cl.parent_id || p1.ancestor_ids) AS ancestors_ids, (c.id || p1.full_path_ids) AS full_path_ids, (c.internal_name || p1.full_path_names) AS full_path_names
        FROM concepts c
        JOIN concept_links cl ON cl.child_id = c.id
        AND cl.link_type = 'broader'
        JOIN child_paths p1 ON p1.id = cl.parent_id
      WHERE c.id <> ALL (p1.full_path_ids) )
      INSERT INTO concept_paths ( id, ancestor_ids, full_path_ids, full_path_names )
      SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id, child_paths.ancestor_ids, child_paths.full_path_ids, child_paths.full_path_names
      FROM child_paths
      ON CONFLICT ON CONSTRAINT concept_paths_pkey
      DO UPDATE
      SET ancestor_ids = EXCLUDED.ancestor_ids, full_path_ids = EXCLUDED.full_path_ids, full_path_names = EXCLUDED.full_path_names
      WHERE concept_paths.ancestor_ids IS DISTINCT
      FROM EXCLUDED.ancestor_ids
      OR concept_paths.full_path_ids IS DISTINCT
      FROM EXCLUDED.full_path_ids
      OR concept_paths.full_path_names IS DISTINCT
      FROM EXCLUDED.full_path_names;
      END IF;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.upsert_concept_paths_transitive(concept_ids uuid[]) RETURNS void LANGUAGE plpgsql AS $function$
      BEGIN
      IF array_length(concept_ids, 1) > 0 THEN
        WITH RECURSIVE paths( id, parent_id, ancestor_ids, full_path_ids, full_path_names, link_types, tree_label_id ) AS (
        SELECT c.id, cl.parent_id, ARRAY []::uuid [], ARRAY [c.id], ARRAY [c.internal_name], CASE WHEN cl.parent_id IS NULL THEN ARRAY []::varchar [] ELSE ARRAY [cl.link_type]::varchar [] END, c.concept_scheme_id
        FROM concepts c
        JOIN concept_links cl ON cl.child_id = c.id
        WHERE c.id = ANY(concept_ids)
        UNION ALL
        SELECT paths.id, cl.parent_id, ancestor_ids || c.id, full_path_ids || c.id, full_path_names || c.internal_name, CASE WHEN cl.parent_id IS NULL THEN paths.link_types ELSE paths.link_types || cl.link_type END, c.concept_scheme_id
        FROM concepts c
        JOIN paths ON paths.parent_id = c.id
        JOIN concept_links cl ON cl.child_id = c.id
        WHERE c.id <> ALL (paths.full_path_ids) ), child_paths( id, ancestor_ids, full_path_ids, full_path_names, link_types ) AS (
        SELECT paths.id, paths.ancestor_ids, paths.full_path_ids, paths.full_path_names || cs.name, array_remove(paths.link_types, NULL)
        FROM paths
        JOIN concept_schemes cs ON cs.id = paths.tree_label_id
        WHERE paths.parent_id IS NULL
        UNION ALL
        SELECT c.id, cl.parent_id || p1.ancestor_ids, c.id || p1.full_path_ids, c.internal_name || p1.full_path_names, cl.link_type || p1.link_types
        FROM concepts c
        JOIN concept_links cl ON cl.child_id = c.id
        JOIN child_paths p1 ON p1.id = cl.parent_id
        WHERE c.id <> ALL (p1.full_path_ids) ), deleted_capt AS (
        DELETE FROM concept_paths_transitive
          WHERE concept_paths_transitive.id IN (
          SELECT capt.id
          FROM concept_paths_transitive capt
          WHERE capt.full_path_ids && concept_ids
            AND NOT EXISTS (
            SELECT 1
            FROM child_paths
          WHERE child_paths.full_path_ids = capt.full_path_ids )
          ORDER BY capt.id ASC FOR
      UPDATE SKIP LOCKED ) )
      INSERT INTO concept_paths_transitive ( concept_id, ancestor_ids, full_path_ids, full_path_names, link_types, mapped_ids )
        SELECT DISTINCT ON (child_paths.full_path_ids) child_paths.id, child_paths.ancestor_ids, child_paths.full_path_ids, child_paths.full_path_names, child_paths.link_types, (
        SELECT COALESCE(array_agg(child_paths.full_path_ids [i]), ARRAY []::uuid [])
        FROM generate_subscripts(child_paths.full_path_ids, 1) AS i
          WHERE EXISTS (
          SELECT 1
          FROM generate_subscripts(child_paths.link_types, 1) AS j
          WHERE j < i
      AND child_paths.link_types [j] = 'related' ) )
      FROM child_paths
      ON CONFLICT ON CONSTRAINT concept_paths_transitive_unique
      DO UPDATE
      SET full_path_names = EXCLUDED.full_path_names, link_types = EXCLUDED.link_types, mapped_ids = EXCLUDED.mapped_ids
      WHERE concept_paths_transitive.full_path_names IS DISTINCT
      FROM EXCLUDED.full_path_names
      OR concept_paths_transitive.link_types IS DISTINCT
      FROM EXCLUDED.link_types
      OR concept_paths_transitive.mapped_ids IS DISTINCT
      FROM EXCLUDED.mapped_ids;
      END IF;
      END; $function$;
    SQL
  end

  # The two path triggers lose their bridge over `classification_groups` for the same reason. And
  # `concepts` has no deleted_at: the projection never held a soft-deleted alias, so the
  # `deleted_at IS NULL` these carried was already a no-op and would now fail to resolve.
  def ccc_trigger_functions
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.delete_ccc_relations_transitive_trigger_1() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations_transitive (ARRAY [OLD.content_data_id]::UUID []);
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.delete_ccc_relations_transitive_trigger_2() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM public.generate_ccc_from_concept_ids_transitive (array_agg(affected_concepts.id))
        FROM (
        SELECT DISTINCT c.id
        FROM old_concept_paths_transitive ocpt
      INNER JOIN concepts c ON c.id = ANY (ocpt.full_path_ids) ) "affected_concepts";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_relations_transitive_trigger_1() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM public.generate_ccc_from_concept_ids_transitive (array_agg(affected_concepts.id))
        FROM (
        SELECT DISTINCT c.id
        FROM new_concept_paths_transitive ncpt
      INNER JOIN concepts c ON c.id = ANY (ncpt.full_path_ids) ) "affected_concepts";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_relations_transitive_trigger_2() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations_transitive (ARRAY [NEW.content_data_id]::UUID []);
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_ccc_relations_transitive_update_trigger_function() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM public.generate_ccc_from_concept_ids_transitive (array_agg(affected_concepts.id))
        FROM (
        SELECT DISTINCT c.id
        FROM new_concept_paths_transitive ncpt
        JOIN old_concept_paths_transitive ocpt ON ocpt.id = ncpt.id
        JOIN concepts c ON c.id = ANY (ncpt.full_path_ids)
        WHERE ncpt.mapped_ids IS DISTINCT
      FROM ocpt.mapped_ids ) "affected_concepts";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_collected_concept_content_relations_trigger_1() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations(ARRAY[NEW.content_data_id]::UUID[]);
      RETURN NEW;
      END;$function$;

      CREATE OR REPLACE FUNCTION public.generate_collected_concept_content_relations_trigger_2() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations(ARRAY[OLD.content_data_id]::UUID[]);
      RETURN NEW;
      END;$function$;

      CREATE OR REPLACE FUNCTION public.generate_collected_concept_content_relations_trigger_3() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations (ARRAY_AGG(content_data_id))
        FROM (
        SELECT DISTINCT concept_contents.content_data_id
        FROM concept_paths
        INNER JOIN concept_contents ON concept_contents.concept_id = concept_paths.id
      WHERE concept_paths.full_path_ids && ARRAY[NEW.id]::uuid[]) "relevant_content_ids";
      RETURN NEW;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_collected_concept_content_relations_trigger_5() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations (ARRAY_AGG(content_data_id))
        FROM (
        SELECT DISTINCT concept_contents.content_data_id
        FROM new_concept_paths
      INNER JOIN concept_contents ON concept_contents.concept_id = ANY ( new_concept_paths.full_path_ids ) ) "collected_concept_content_relations_alias";
      RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.generate_concept_links_ccc_relations_trigger_1() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations (ARRAY_AGG(to_update.content_data_id))
        FROM (
        SELECT DISTINCT cc.content_data_id
        FROM changed_concept_links
        JOIN concepts c1 ON c1.id = changed_concept_links.parent_id
        JOIN concept_contents cc ON cc.concept_id = c1.id
        WHERE c1.id IS NOT NULL
        AND changed_concept_links.link_type = 'related'
        UNION
        SELECT DISTINCT cc.content_data_id
        FROM changed_concept_links
        JOIN concepts c1 ON c1.id = changed_concept_links.child_id
        JOIN concept_contents cc ON cc.concept_id = c1.id
        WHERE c1.id IS NOT NULL
      AND changed_concept_links.link_type = 'related' ) AS to_update;
      RETURN NEW;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.update_concept_links_ccc_relations_trigger_1() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
      PERFORM generate_collected_concept_content_relations (ARRAY_AGG(to_update.content_data_id))
        FROM (
        SELECT DISTINCT cc.content_data_id
        FROM old_concept_links
        JOIN concepts c1 ON c1.id = old_concept_links.parent_id
        JOIN concept_contents cc ON cc.concept_id = c1.id
        WHERE c1.id IS NOT NULL
        AND old_concept_links.link_type = 'related'
        UNION
        SELECT DISTINCT cc.content_data_id
        FROM old_concept_links
        JOIN concepts c1 ON c1.id = old_concept_links.child_id
        JOIN concept_contents cc ON cc.concept_id = c1.id
        WHERE c1.id IS NOT NULL
        AND old_concept_links.link_type = 'related'
        UNION
        SELECT DISTINCT cc.content_data_id
        FROM new_concept_links
        JOIN concepts c1 ON c1.id = new_concept_links.parent_id
        JOIN concept_contents cc ON cc.concept_id = c1.id
        WHERE c1.id IS NOT NULL
        AND new_concept_links.link_type = 'related'
        UNION
        SELECT DISTINCT cc.content_data_id
        FROM new_concept_links
        JOIN concepts c1 ON c1.id = new_concept_links.child_id
        JOIN concept_contents cc ON cc.concept_id = c1.id
        WHERE c1.id IS NOT NULL
      AND new_concept_links.link_type = 'related' ) AS to_update;
      RETURN NEW;
      END; $function$;
    SQL
  end

  # `to_thing_history` only follows the renamed content-history writer.
  def history_functions
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.to_concept_content_history(content_id uuid, new_history_id uuid) RETURNS void LANGUAGE plpgsql AS $function$ DECLARE insert_query TEXT;
      BEGIN
      SELECT 'INSERT INTO concept_content_histories (content_data_history_id, ' || string_agg(column_name, ', ') || ') SELECT ''' || new_history_id || '''::UUID, ' || string_agg('t.' || column_name, ', ') || ' FROM concept_contents t WHERE t.content_data_id = ''' || content_id || '''::UUID;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'concept_content_histories'
      AND column_name NOT IN ('id', 'content_data_history_id');
      EXECUTE insert_query;
      RETURN;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.to_thing_history(content_id uuid, current_locale character varying, all_translations boolean DEFAULT false, deleted boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql AS $function$ DECLARE insert_query TEXT;
      new_history_id UUID;
      BEGIN
      SELECT 'INSERT INTO thing_histories (thing_id, deleted_at, ' || string_agg(column_name, ', ') || ') SELECT t.id, CASE WHEN t.deleted_at IS NOT NULL THEN t.deleted_at WHEN ' || deleted || '::BOOLEAN THEN transaction_timestamp() ELSE NULL END, ' || string_agg('t.' || column_name, ', ') || ' FROM things t WHERE t.id = ''' || content_id || '''::UUID LIMIT 1 RETURNING id;' INTO insert_query
      FROM information_schema.columns
      WHERE table_name = 'thing_histories'
      AND column_name NOT IN ('id', 'thing_id', 'deleted_at');
      EXECUTE insert_query INTO new_history_id;
      IF new_history_id IS NULL THEN
      RETURN NULL;
      END IF;
      PERFORM to_thing_history_translation ( content_id, new_history_id, current_locale, all_translations );
      PERFORM to_concept_content_history (content_id, new_history_id);
      PERFORM to_content_content_history ( content_id, new_history_id, current_locale, all_translations, deleted );
      PERFORM to_schedule_history (content_id, new_history_id);
      PERFORM to_content_collection_link_history (content_id, new_history_id);
      PERFORM to_geometry_history (content_id, new_history_id);
      PERFORM to_embedding_history (content_id, new_history_id);
      RETURN new_history_id;
      END; $function$;
    SQL
  end

  # order_a used to be maintained from `classification_aliases` and `classification_trees`; it now
  # hangs off `concepts` and the `broader` links. The recursion is the same walk - a root is a
  # `broader` link without a parent, and the tree label is `concepts.concept_scheme_id` - and it
  # was verified to assign the identical order_a to all 57,846 concepts before the cut.
  #
  # The reorder writes concepts.order_a and so re-fires its own trigger, exactly as the legacy pair
  # did: the second pass finds nothing left to change, updates no row, and the empty transition
  # table ends it.
  def order_a_functions
    <<~SQL.squish
      CREATE OR REPLACE FUNCTION public.update_concepts_order_a(concept_scheme_ids uuid[]) RETURNS void LANGUAGE plpgsql AS $function$
      BEGIN
        IF array_length(concept_scheme_ids, 1) > 0 THEN
          UPDATE concepts
          SET order_a = w.order_a
          FROM (
            WITH RECURSIVE paths (id, updated_at, full_order_a, concept_scheme_id) AS (
              SELECT c.id, c.updated_at,
                ARRAY [(ROW_NUMBER() OVER (PARTITION BY c.concept_scheme_id ORDER BY c.order_a ASC, c.updated_at ASC))],
                c.concept_scheme_id
              FROM concept_links cl
              JOIN concepts c ON c.id = cl.child_id
              WHERE cl.link_type = 'broader'
                AND cl.parent_id IS NULL
                AND c.concept_scheme_id = ANY (concept_scheme_ids)
              UNION
              SELECT cl.child_id, c.updated_at,
                paths.full_order_a || (ROW_NUMBER() OVER (PARTITION BY c.concept_scheme_id ORDER BY paths.full_order_a || c.order_a::BIGINT ASC, c.updated_at ASC)),
                c.concept_scheme_id
              FROM concept_links cl
              JOIN paths ON paths.id = cl.parent_id
              JOIN concepts c ON c.id = cl.child_id
              WHERE cl.link_type = 'broader'
            )
            SELECT paths.id,
              (ROW_NUMBER() OVER (PARTITION BY cs.id ORDER BY paths.full_order_a ASC, paths.updated_at ASC)) AS order_a
            FROM paths
            JOIN concept_schemes cs ON cs.id = paths.concept_scheme_id
          ) w
          WHERE w.id = concepts.id
            AND concepts.order_a IS DISTINCT FROM w.order_a;
        END IF;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.update_concepts_order_a_trigger() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
        PERFORM update_concepts_order_a(ARRAY_AGG(concept_scheme_id))
        FROM (
          SELECT DISTINCT nc.concept_scheme_id
          FROM new_concepts nc
          JOIN old_concepts oc ON oc.id = nc.id
          WHERE nc.concept_scheme_id IS NOT NULL
            AND ((oc.order_a IS DISTINCT FROM nc.order_a AND nc.order_a IS NOT NULL)
              OR oc.concept_scheme_id IS DISTINCT FROM nc.concept_scheme_id)
          UNION
          SELECT DISTINCT oc.concept_scheme_id
          FROM new_concepts nc
          JOIN old_concepts oc ON oc.id = nc.id
          WHERE oc.concept_scheme_id IS NOT NULL
            AND oc.concept_scheme_id IS DISTINCT FROM nc.concept_scheme_id
        ) "affected_concept_schemes";
        RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.insert_concept_links_order_a_trigger() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
        PERFORM update_concepts_order_a(ARRAY_AGG(concept_scheme_id))
        FROM (
          SELECT DISTINCT c.concept_scheme_id
          FROM new_concept_links ncl
          JOIN concepts c ON c.id = ncl.child_id
          WHERE ncl.link_type = 'broader'
            AND c.concept_scheme_id IS NOT NULL
        ) "affected_concept_schemes";
        RETURN NULL;
      END; $function$;

      CREATE OR REPLACE FUNCTION public.update_concept_links_order_a_trigger() RETURNS trigger LANGUAGE plpgsql AS $function$
      BEGIN
        PERFORM update_concepts_order_a(ARRAY_AGG(concept_scheme_id))
        FROM (
          SELECT DISTINCT c.concept_scheme_id
          FROM new_concept_links ncl
          JOIN old_concept_links ocl ON ocl.id = ncl.id
          JOIN concepts c ON c.id = ncl.child_id
          WHERE ncl.link_type = 'broader'
            AND c.concept_scheme_id IS NOT NULL
            AND ncl.parent_id IS DISTINCT FROM ocl.parent_id
        ) "affected_concept_schemes";
        RETURN NULL;
      END; $function$;
    SQL
  end
end
