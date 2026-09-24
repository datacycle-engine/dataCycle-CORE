# frozen_string_literal: true

require 'test_helper'
require DataCycleCore::Engine.root.join('db', 'migrate', '20260907120000_replace_classifications_with_concepts')

module DataCycleCore
  # The steps are exercised one at a time: the test schema is already post-cut, so `up` as a whole has
  # no legacy tables to read. `remap_user_group_concepts` stays reachable there because it resolves
  # over `classification_groups` rather than over `concepts.classification_id`, a column this schema
  # no longer has - the three tables it reads are the only ones to recreate.
  class ReplaceClassificationsWithConceptsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def setup
      @concepts = DataCycleCore::Concept.order(:id).limit(3).pluck(:id)
      @user_group = DataCycleCore::UserGroup.create!(name: 'concept remap')
      @other_group = DataCycleCore::UserGroup.create!(name: 'concept remap other')
      create_legacy_tables
    end

    def teardown
      ActiveRecord::Base.connection.execute(
        'DROP TABLE IF EXISTS classification_user_groups, classification_groups, classifications, ' \
        'classification_polygons, classification_aliases, classification_alias_paths, ' \
        'classification_alias_paths_transitive; DROP FUNCTION IF EXISTS legacy_ccc_tripwire'
      )
      DataCycleCore::UserGroup.where(id: [@user_group.id, @other_group.id]).delete_all
      DataCycleCore::Feature::TransitiveClassificationPath.update_triggers(false)
    end

    test 'every assignment lands on the concepts its classification resolved to' do
      plain = create_classification(@concepts[0])
      # one classification mapped onto two aliases resolved to both on the association chain, so it
      # has to become two rows rather than an arbitrarily chosen one
      fanned_out = create_classification(@concepts[1], @concepts[2])
      # two classifications mapped onto the same alias collapse to one row
      shared_one = create_classification(@concepts[0])
      shared_two = create_classification(@concepts[0])

      assign(@user_group, plain, fanned_out)
      assign(@other_group, shared_one, shared_two)

      remap!

      assert_equal [@concepts[0], @concepts[1], @concepts[2]].sort, remapped_ids(@user_group).sort
      assert_equal [@concepts[0]], remapped_ids(@other_group)
    end

    test 'an assignment that resolves to no concept is dropped rather than left dangling' do
      no_live_group = create_classification(@concepts[0], deleted_group: true)
      soft_deleted = create_classification(@concepts[1], deleted_at: Time.zone.now)

      assign(@user_group, no_live_group, soft_deleted)

      remap!

      assert_empty remapped_ids(@user_group)
    end

    # A seeded schema already carries the right trigger state, which is what let the cut ship without
    # it: the enabled state `create_triggers` leaves is reproduced here rather than assumed.
    test 'the transitive triggers on concept_contents end up in the state the ones on concepts are in' do
      enable_concept_contents_transitive_triggers

      assert_not_equal transitive_trigger_states('concepts'), transitive_trigger_states('concept_contents'),
                       'setup must reproduce the state create_triggers leaves'

      ReplaceClassificationsWithConcepts.new.send(:apply_transitive_trigger_state)

      assert_equal transitive_trigger_states('concepts').uniq, transitive_trigger_states('concept_contents').uniq
    end

    # The step above is reachable on this schema, `up` as a whole is not - so what keeps the step
    # wired into it is asserted on the source. Dropping the call is the defect itself: every deploy
    # would then migrate with concept_contents' transitive triggers left enabled.
    test 'up runs the trigger state step' do
      assert_includes up_steps, 'apply_transitive_trigger_state'
    end

    # A plpgsql function resolves the tables it names when it runs, so the CCC maintenance layer on
    # the legacy path tables outlives the `classification_contents` build_concept_contents drops and
    # takes the migration down on the delete purge_stale_transitive_paths runs two steps later. The
    # tripwire stands in for `generate_ccc_from_ca_ids_transitive`, which this schema no longer
    # carries; what it asserts is the same thing - after the step, that delete fires nothing.
    test 'the legacy path triggers are gone before a transitive path delete can fire them' do
      create_legacy_path_tables

      ActiveRecord::Migration.suppress_messages do
        ReplaceClassificationsWithConcepts.new.send(:drop_legacy_ccc_triggers)
      end

      assert_empty legacy_path_trigger_names
      assert_nothing_raised do
        ActiveRecord::Base.connection.execute('DELETE FROM classification_alias_paths_transitive')
      end
    end

    # Where the step sits is the other half of it: placed after build_concept_contents, it would
    # drop the five only once that step has already let them fire.
    test 'up drops the legacy ccc triggers before the table their functions read goes' do
      steps = up_steps

      assert_includes steps, 'drop_legacy_ccc_triggers'
      assert_operator steps.index('drop_legacy_ccc_triggers'), :<, steps.index('build_concept_contents')
    end

    test 'a polygon outliving its soft-deleted alias goes, one whose alias is live stays' do
      live = create_alias_with_polygon
      create_alias_with_polygon(deleted_at: Time.zone.now)

      ActiveRecord::Migration.suppress_messages do
        ReplaceClassificationsWithConcepts.new.send(:drop_polygons_of_deleted_aliases)
      end

      assert_equal [live], polygon_alias_ids
    end

    # `backfill_projection_gaps` writes `concepts.classification_id`, a column this schema no longer
    # has, so the step itself is out of reach here and only its place in `up` can be asserted. That
    # place is the whole point of it: run after the guard, it would repair a projection the deploy
    # has already aborted over, and run after drop_legacy_tables it would have nothing left to read.
    test 'up closes the projection gaps before it checks the preconditions' do
      steps = up_steps

      assert_operator steps.index('backfill_projection_gaps'), :<, steps.index('verify_rebuild_preconditions!')
      assert_operator steps.index('drop_polygons_of_deleted_aliases'), :<, steps.index('verify_rebuild_preconditions!')
    end

    private

    def up_steps
      source = File.read(
        DataCycleCore::Engine.root.join('db', 'migrate', '20260907120000_replace_classifications_with_concepts.rb')
      )

      source[/^  def up$(.*?)^  end$/m, 1].lines.map(&:strip).grep_v(/\A(#|\z)/)
    end

    def create_alias_with_polygon(deleted_at: nil)
      id = SecureRandom.uuid
      insert('classification_aliases', id:, deleted_at:)
      insert('classification_polygons', id: SecureRandom.uuid, classification_alias_id: id)
      id
    end

    def polygon_alias_ids
      ActiveRecord::Base.connection.select_values('SELECT classification_alias_id FROM classification_polygons')
    end

    def enable_concept_contents_transitive_triggers
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        ALTER TABLE concept_contents ENABLE TRIGGER generate_ccc_relations_transitive_trigger;
        ALTER TABLE concept_contents ENABLE TRIGGER delete_ccc_relations_transitive_trigger;
        ALTER TABLE concept_contents ENABLE TRIGGER update_ccc_relations_transitive_trigger;
      SQL
    end

    def transitive_trigger_states(table)
      ActiveRecord::Base.connection.select_values(
        ActiveRecord::Base.sanitize_sql([<<~SQL.squish, table])
          SELECT t.tgenabled FROM pg_trigger t
          JOIN pg_class c ON c.oid = t.tgrelid
          WHERE c.relname = ? AND t.tgname LIKE '%transitive%' AND NOT t.tgisinternal
          ORDER BY t.tgname
        SQL
      )
    end

    def remap!
      ActiveRecord::Migration.suppress_messages do
        ReplaceClassificationsWithConcepts.new.send(:remap_user_group_concepts)
      end
    end

    def remapped_ids(user_group)
      ActiveRecord::Base.connection.select_values(
        ActiveRecord::Base.sanitize_sql(
          ['SELECT classification_id FROM classification_user_groups WHERE user_group_id = ?', user_group.id]
        )
      )
    end

    def create_classification(*concept_ids, deleted_at: nil, deleted_group: false)
      id = SecureRandom.uuid
      insert('classifications', id:, deleted_at:)
      concept_ids.each do |concept_id|
        insert('classification_groups', id: SecureRandom.uuid, classification_id: id,
                                        classification_alias_id: concept_id,
                                        deleted_at: deleted_group ? Time.zone.now : nil)
      end
      id
    end

    def assign(user_group, *classification_ids)
      classification_ids.each do |classification_id|
        insert('classification_user_groups', id: SecureRandom.uuid, classification_id:,
                                             user_group_id: user_group.id, created_at: Time.zone.now,
                                             updated_at: Time.zone.now)
      end
    end

    def insert(table, **values)
      columns = values.keys.join(', ')
      placeholders = Array.new(values.size, '?').join(', ')
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.sanitize_sql(["INSERT INTO #{table} (#{columns}) VALUES (#{placeholders})", *values.values])
      )
    end

    def legacy_path_trigger_names
      ActiveRecord::Base.connection.select_values(<<~SQL.squish)
        SELECT t.tgname FROM pg_trigger t
        JOIN pg_class c ON c.oid = t.tgrelid
        WHERE c.relname IN ('classification_alias_paths', 'classification_alias_paths_transitive')
          AND NOT t.tgisinternal
      SQL
    end

    # The row and the INSERT trigger are ordered so that the seeding does not trip the tripwire
    # itself: a statement-level trigger fires on a delete of no rows just as well, but a delete of
    # one is what the step has to survive.
    def create_legacy_path_tables
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        CREATE TABLE classification_alias_paths (id uuid PRIMARY KEY DEFAULT gen_random_uuid());
        CREATE TABLE classification_alias_paths_transitive (id uuid PRIMARY KEY DEFAULT gen_random_uuid());
        INSERT INTO classification_alias_paths_transitive DEFAULT VALUES;

        CREATE FUNCTION legacy_ccc_tripwire() RETURNS trigger LANGUAGE plpgsql AS $$
          BEGIN RAISE EXCEPTION 'legacy ccc trigger fired'; END;
        $$;

        CREATE TRIGGER generate_collected_classification_content_relations_trigger
          AFTER INSERT ON classification_alias_paths
          FOR EACH STATEMENT EXECUTE FUNCTION legacy_ccc_tripwire();
        CREATE TRIGGER update_collected_classification_content_relations_trigger
          AFTER UPDATE ON classification_alias_paths
          FOR EACH ROW EXECUTE FUNCTION legacy_ccc_tripwire();
        CREATE TRIGGER delete_ccc_relations_transitive_trigger
          AFTER DELETE ON classification_alias_paths_transitive
          FOR EACH STATEMENT EXECUTE FUNCTION legacy_ccc_tripwire();
        CREATE TRIGGER generate_ccc_relations_transitive_trigger
          AFTER INSERT ON classification_alias_paths_transitive
          FOR EACH STATEMENT EXECUTE FUNCTION legacy_ccc_tripwire();
        CREATE TRIGGER generate_ccc_relations_transitive_update_trigger
          AFTER UPDATE ON classification_alias_paths_transitive
          FOR EACH STATEMENT EXECUTE FUNCTION legacy_ccc_tripwire();
      SQL
    end

    def create_legacy_tables
      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        CREATE TABLE classifications (id uuid PRIMARY KEY, deleted_at timestamp);
        CREATE TABLE classification_groups (
          id uuid PRIMARY KEY, classification_id uuid, classification_alias_id uuid, deleted_at timestamp
        );
        CREATE TABLE classification_user_groups (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(), classification_id uuid, user_group_id uuid,
          seen_at timestamp, created_at timestamp NOT NULL, updated_at timestamp NOT NULL
        );
        CREATE TABLE classification_aliases (id uuid PRIMARY KEY, deleted_at timestamp);
        CREATE TABLE classification_polygons (
          id uuid PRIMARY KEY DEFAULT gen_random_uuid(), classification_alias_id uuid
        );
      SQL
    end
  end
end
