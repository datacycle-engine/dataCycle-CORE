# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StoredFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @current_user = User.find_by(email: 'tester@datacycle.at')
      @person_and_organization_ids = DataCycleCore::ClassificationAlias
        .for_tree('Inhaltstypen')
        .with_internal_name(['Person', 'Organisation']).pluck(:id)
      @expected_parameters = [{ 't' => 'classification_alias_ids', 'm' => 'i', 'n' => 'Inhaltstypen', 'v' => @person_and_organization_ids, 'c' => 'a' }].to_set
      @previous_user_filters = DataCycleCore.user_filters.deep_dup
    end

    after(:all) do
      DataCycleCore.user_filters = @previous_user_filters
    end

    # every set-like consumer (thing_ids, the SQL representation, dc:clean_up:archive_orphans) needs
    # the sort gone: a name sort orders by thing_translations.content ->> 'name', which Postgres
    # rejects next to SELECT DISTINCT
    test 'unsorted_things drops the sort a name-sorted filter would apply' do
      stored_filter = DataCycleCore::StoredFilter.new(language: ['de'], sort_parameters: [{ 'm' => 'name', 'o' => 'ASC' }])

      assert_includes stored_filter.dup.things.to_sql, 'ORDER BY'
      assert_not_includes stored_filter.unsorted_things.to_sql, 'ORDER BY'
    end

    test 'unsorted_things drops the default sort of a filter without sort parameters' do
      stored_filter = DataCycleCore::StoredFilter.new(language: ['de'])

      assert_not_includes stored_filter.unsorted_things.to_sql, 'ORDER BY'
    end

    test 'parameters_from_hash with stringified hash' do
      stored_filter = DataCycleCore::StoredFilter.new
      params = [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }]

      assert_equal @expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal @expected_parameters, stored_filter.parameters.to_set
    end

    test 'parameters_from_hash with symbolized hash' do
      stored_filter = DataCycleCore::StoredFilter.new
      params = [{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Person', 'Organisation'] } }]

      assert_equal @expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal @expected_parameters, stored_filter.parameters.to_set
    end

    test 'parameters_from_hash with ActionController::Parameters' do
      stored_filter = DataCycleCore::StoredFilter.new
      params = [
        ActionController::Parameters.new(
          with_classification_aliases_and_treename: ActionController::Parameters.new(
            treeLabel: 'Inhaltstypen', aliases: ['Person', 'Organisation']
          ).permit!
        ).permit!
      ]

      assert_equal @expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal @expected_parameters, stored_filter.parameters.to_set
    end

    test 'parameters_from_hash overrides previous parameters' do
      stored_filter = DataCycleCore::StoredFilter.new(parameters: [{ 't' => 'test', 'v' => 'test' }])
      params = [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }]

      assert_equal @expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal @expected_parameters, stored_filter.parameters.to_set
    end

    test 'apply_user_filter with empty parameters' do
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, nil).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: nil }).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: '' }).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { template_name: '' }).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { template_name: nil }).parameters
    end

    test 'get correct filter_params from definition' do
      stored_filter = DataCycleCore::StoredFilter.new.parameters_from_hash([{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }])

      assert_equal @expected_parameters, stored_filter.parameters.to_set

      stored_filter = DataCycleCore::StoredFilter.new.parameters_from_hash([{ 'external_source' => ['nil'] }])

      assert_equal [{ 't' => 'external_system', 'm' => 'i', 'v' => ['nil'], 'c' => 'a', 'n' => 'External_system', 'q' => 'import' }].to_set, stored_filter.parameters.to_set

      stored_filter = DataCycleCore::StoredFilter.new.parameters_from_hash([{ 'not_external_source' => ['nil'] }])

      assert_equal [{ 't' => 'external_system', 'm' => 'e', 'v' => ['nil'], 'c' => 'a', 'n' => 'External_system', 'q' => 'import' }].to_set, stored_filter.parameters.to_set
    end

    test 'user_filters get set correctly' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'scope' => ['backend'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      stored_filter = DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: 'backend' })

      assert_equal [], stored_filter.parameters
      assert_equal [{ 't' => 'classification_alias_ids', 'm' => 'i', 'n' => 'Inhaltstypen', 'v' => @person_and_organization_ids, 'c' => 'u' }].to_set, stored_filter.user_filter_parameters.to_set

      DataCycleCore.user_filters = @previous_user_filters
    end

    test 'forced user_filters get set correctly' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['backend'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      stored_filter = DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: 'backend' })

      assert_equal [], stored_filter.parameters
      assert_equal [{ 't' => 'classification_alias_ids', 'm' => 'i', 'n' => 'Inhaltstypen', 'v' => @person_and_organization_ids, 'c' => 'uf' }].to_set, stored_filter.user_filter_parameters.to_set

      DataCycleCore.user_filters = @previous_user_filters
    end

    test 'forced user_filters get set correctly for api_linked scope' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['api_linked'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      stored_filter = DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: 'api_linked' })

      assert_equal [], stored_filter.parameters
      assert_equal [{ 't' => 'classification_alias_ids', 'm' => 'i', 'n' => 'Inhaltstypen', 'v' => @person_and_organization_ids, 'c' => 'uf' }].to_set, stored_filter.user_filter_parameters.to_set

      DataCycleCore.user_filters = @previous_user_filters
    end

    test 'api_linked user_filters are not applied for other scopes' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['api_linked'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: 'api' }).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: 'backend' }).parameters

      DataCycleCore.user_filters = @previous_user_filters
    end

    test 'apply_user_filter preserves a preset id (as used for api_linked stored_filters)' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['api_linked'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      preset_id = '00000000-0000-0000-0000-0000000000ab'
      stored_filter = DataCycleCore::StoredFilter.new(id: preset_id).apply_user_filter(@current_user, { scope: 'api_linked' })

      assert_equal preset_id, stored_filter.id
      assert(stored_filter.user_filter_parameters.any? { |f| f['c'] == 'uf' })

      DataCycleCore.user_filters = @previous_user_filters
    end

    test 'parameters_with_user_filters merges the resolved user filters into the effective filter set' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'scope' => ['backend'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      stored_filter = DataCycleCore::StoredFilter.new.parameters_from_hash([{ 'external_source' => ['nil'] }])
      base_parameters = stored_filter.parameters.deep_dup
      stored_filter.apply_user_filter(@current_user, { scope: 'backend' })

      assert_equal 1, stored_filter.user_filter_parameters.size
      # the read path keeps user filters out of `parameters` so the query cache stays usable ...
      assert_equal base_parameters, stored_filter.parameters
      # ... while parameters_with_user_filters (the effective set, used for the dashboard chips) merges
      # them in on top, without duplicates.
      assert_equal base_parameters + stored_filter.user_filter_parameters, stored_filter.parameters_with_user_filters

      DataCycleCore.user_filters = @previous_user_filters
    end

    test 'a user filter equal to a base parameter (ignoring context) is deduped and adds no duplicate' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['backend'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      # a base parameter that filters the same classifications as the forced user filter, but as a plain
      # (removable, `c: 'a'`) parameter - i.e. equal to the user filter ignoring context.
      base_param = { 't' => 'classification_alias_ids', 'm' => 'i', 'n' => 'Inhaltstypen', 'v' => @person_and_organization_ids, 'c' => 'a' }
      stored_filter = DataCycleCore::StoredFilter.new(parameters: [base_param.deep_dup])
      stored_filter.apply_user_filter(@current_user, { scope: 'backend' })

      # the base parameter is baked into the cache and applied live regardless of its context, so it already
      # enforces the filter: the forced user filter is not re-applied live (consider_context: false) and
      # adds no duplicate to the effective filter set.
      assert_empty stored_filter.user_filter_parameters
      assert_equal [base_param], stored_filter.parameters_with_user_filters

      DataCycleCore.user_filters = @previous_user_filters
    end
  end
end
