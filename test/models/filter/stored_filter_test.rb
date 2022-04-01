# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StoredFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @current_user = User.find_by(email: 'tester@datacycle.at')
    end

    test 'parameters_from_hash with stringified hash' do
      stored_filter = DataCycleCore::StoredFilter.new
      params = [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }]
      expected_parameters = [{ 't' => 'with_classification_aliases_and_treename', 'v' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }].to_set

      assert_equal expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal expected_parameters, stored_filter.parameters.to_set
    end

    test 'parameters_from_hash with symbolized hash' do
      stored_filter = DataCycleCore::StoredFilter.new
      params = [{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Person', 'Organisation'] } }]
      expected_parameters = [{ 't' => 'with_classification_aliases_and_treename', 'v' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }].to_set

      assert_equal expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal expected_parameters, stored_filter.parameters.to_set
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
      expected_parameters = [{ 't' => 'with_classification_aliases_and_treename', 'v' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }].to_set

      assert_equal expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal expected_parameters, stored_filter.parameters.to_set
    end

    test 'parameters_from_hash overrides previous parameters' do
      stored_filter = DataCycleCore::StoredFilter.new(parameters: [{ 't' => 'test', 'v' => 'test' }])
      params = [{ 'with_classification_aliases_and_treename' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }]
      expected_parameters = [{ 't' => 'with_classification_aliases_and_treename', 'v' => { 'treeLabel' => 'Inhaltstypen', 'aliases' => ['Person', 'Organisation'] } }].to_set

      assert_equal expected_parameters, stored_filter.parameters_from_hash(params).parameters.to_set
      assert_equal expected_parameters, stored_filter.parameters.to_set
    end

    test 'apply_user_filter with empty parameters' do
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, nil).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: nil }).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { scope: '' }).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { template_name: '' }).parameters
      assert_equal [], DataCycleCore::StoredFilter.new.apply_user_filter(@current_user, { template_name: nil }).parameters
    end
  end
end
