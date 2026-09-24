# frozen_string_literal: true

require 'test_helper'
require DataCycleCore::Engine.root.join('db', 'data_migrate', '20260908090000_rename_classification_filters_to_concept_filters')

module DataCycleCore
  # [#41458] The rewrite runs as one REPLACE chain over `parameters::text`, so what it can reach is
  # decided by jsonb's own rendering rather than by the filter structure: this pins that the `"k":
  # "v"` spelling the pairs are built from is the spelling jsonb produces, at every nesting depth.
  class RenameClassificationFiltersToConceptFiltersMigrationTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
    end

    def stored_filter(parameters)
      filter = DataCycleCore::StoredFilter.create!(user_id: @user.id, language: ['de'])
      filter.update_columns(parameters:)
      filter
    end

    # resync_sql_representations rebuilds every named stored filter in the database, which is the
    # deploy's concern and not this rule's
    def run_migration
      migration = RenameClassificationFiltersToConceptFilters.new
      migration.stub(:resync_sql_representations, nil) do
        migration.suppress_messages { migration.up }
      end
    end

    test 'rewrites every key the pair matrix covers, at both nesting depths' do
      filter = stored_filter([
                               { 'c' => 'd', 'm' => 'i', 'n' => 'SchemaTypes', 't' => 'classification_alias_ids', 'v' => ['x'] },
                               { 'c' => 'd', 'm' => 'i', 't' => 'classification_alias_ids_with_subtree', 'v' => ['x'] },
                               { 'c' => 'd', 'm' => 'i', 't' => 'classification_alias_ids_without_subtree_with_related', 'v' => ['x'] },
                               { 'c' => 'd', 'm' => 'i', 't' => 'classification_alias_ids_related', 'v' => ['x'] },
                               # the one name that never had an implementation - a raising stub pre-cut, so
                               # dropping it would cost the filter its predicate instead of raising
                               { 'c' => 'd', 'm' => 'i', 't' => 'with_classification_alias_ids_without_recursion', 'v' => ['x'] },
                               { 'c' => 'd', 'm' => 'i', 'n' => 'Not_classification_alias_ids', 't' => 'not_classification_alias_ids', 'v' => ['x'] },
                               { 'c' => 'd', 'm' => 'i', 't' => 'advanced_attributes', 'q' => 'classification_alias_ids', 'v' => ['x'] },
                               # param_from_definition falls back to `t.capitalize` when no scheme name is at hand
                               { 'c' => 'd', 'm' => 'i', 'n' => 'Classification_tree_ids', 't' => 'classification_tree_ids', 'v' => ['x'] },
                               { 'c' => 'd', 'm' => 'i', 't' => 'union', 'v' => [[{ 'c' => 'd', 'm' => 'i', 't' => 'classification_alias_ids', 'v' => ['x'] }]] }
                             ])

      run_migration

      assert_equal(
        [
          { 'c' => 'd', 'm' => 'i', 'n' => 'SchemaTypes', 't' => 'concept_ids', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 't' => 'concept_ids_with_subtree', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 't' => 'concept_ids_without_subtree_with_related', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 't' => 'concept_ids_related', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 't' => 'concept_ids_without_subtree', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 'n' => 'Not_concept_ids', 't' => 'not_concept_ids', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 't' => 'advanced_attributes', 'q' => 'concept_ids', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 'n' => 'Concept_scheme_ids', 't' => 'concept_scheme_ids', 'v' => ['x'] },
          { 'c' => 'd', 'm' => 'i', 't' => 'union', 'v' => [[{ 'c' => 'd', 'm' => 'i', 't' => 'concept_ids', 'v' => ['x'] }]] }
        ],
        filter.reload.parameters
      )
    end

    test 'every name the rename produces is answered by the query, in both polarities' do
      # apply_single_filter! is a `return unless query.respond_to?(t)`, so a name that lands here
      # without a method behind it costs the stored filter its predicate rather than raising, and
      # `m` turns the same `t` into its not_ form on the way in
      query = DataCycleCore::Filter::Search.new(locale: ['de'])

      RenameClassificationFiltersToConceptFilters::FILTER_RENAMES.each_value do |name|
        assert_respond_to query, name
        assert_respond_to query, "not_#{name}"
      end
    end

    test 'anchors on the key, so a filter value spelling one of the names is left alone' do
      filter = stored_filter([{ 'c' => 'd', 'm' => 'i', 't' => 'advanced_attributes', 'v' => ['classification_alias_ids'] }])

      run_migration

      assert_equal ['classification_alias_ids'], filter.reload.parameters.first['v']
    end

    test 'is irreversible' do
      assert_raises(ActiveRecord::IrreversibleMigration) { RenameClassificationFiltersToConceptFilters.new.down }
    end
  end
end
