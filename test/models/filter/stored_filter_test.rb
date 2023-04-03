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
      assert_equal [{ 't' => 'classification_alias_ids', 'm' => 'i', 'n' => 'Inhaltstypen', 'v' => @person_and_organization_ids, 'c' => 'u' }].to_set, stored_filter.parameters.to_set

      DataCycleCore.user_filters = @previous_user_filters
    end

    test 'forced user_filters get set correctly' do
      DataCycleCore.user_filters = { tmp1: { 'segments' => [{ 'name' => 'DataCycleCore::Abilities::Segments::UsersByRole', 'parameters' => ['admin'] }], 'force' => true, 'scope' => ['backend'], 'stored_filter' => [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }] } }

      stored_filter = DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: 'backend' })
      assert_equal [{ 't' => 'classification_alias_ids', 'm' => 'i', 'n' => 'Inhaltstypen', 'v' => @person_and_organization_ids, 'c' => 'uf' }].to_set, stored_filter.parameters.to_set

      DataCycleCore.user_filters = @previous_user_filters
    end
  end
end
