# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Type
    module StoredFilter
      class ParametersTest < DataCycleCore::TestCases::ActiveSupportTestCase
        Params = DataCycleCore::Type::StoredFilter::Parameters

        test 'param_from_definition returns the filter as-is when it already has a type key' do
          assert_equal({ 't' => 'name' }, Params.param_from_definition({ 't' => 'name' }))
        end

        test 'transform_union flattens nested stored filters and keeps the name' do
          result = Params.param_from_definition({ 'union' => { 'name' => 'My Union', 'stored_filter' => [{ 'creator' => 'x' }] } })

          assert_equal 'union', result['t']
          assert_equal 'My Union', result['n']
          assert_equal 'user', result['v'].first['t']
        end

        test 'transform_external_system maps value and type' do
          result = Params.param_from_definition({ 'external_system' => { 'value' => 'sys', 'type' => 'export' } })

          assert_equal 'sys', result['v']
          assert_equal 'export', result['q']
        end

        test 'transform_external_system defaults the query to import' do
          result = Params.param_from_definition({ 'external_system' => 'sys' })

          assert_equal 'import', result['q']
        end

        test 'transform_user_group_classifications uses the user id' do
          user = Object.new
          user.define_singleton_method(:id) { 'user-1' }

          result = Params.param_from_definition({ 'user_group_classifications' => 'x' }, 'a', user)

          assert_equal 'user-1', result['v']
        end

        test 'transform_creator rewrites the filter to a creator query' do
          result = Params.param_from_definition({ 'creator' => 'x' })

          assert_equal 'user', result['t']
          assert_equal 'creator', result['q']
        end

        test 'transform_graph_filter extracts query, name and value' do
          result = Params.param_from_definition({ 'graph_filter' => { 'query' => 'q', 'name' => 'nm', 'value' => 'vv' } })

          assert_equal 'q', result['n']
          assert_equal 'nm', result['q']
          assert_equal 'vv', result['v']
        end

        test 'transform_placeholders replaces current_user in arrays and strings' do
          user = Object.new
          user.define_singleton_method(:id) { 'user-2' }

          array_result = Params.param_from_definition({ 'foo' => ['current_user'] }, 'a', user)
          string_result = Params.param_from_definition({ 'bar' => 'current_user' }, 'a', user)

          assert_equal ['user-2'], array_result['v']
          assert_equal 'user-2', string_result['v']
        end

        test 'with_classification_paths resolves classification alias ids by full path' do
          hash = { 'v' => ['Tags > Sub'] }

          Params.with_classification_paths(hash, nil)

          assert_equal 'classification_alias_ids', hash['t']
          assert_equal 'Tags', hash['n']
          assert_kind_of Array, hash['v']
        end

        test 'with_user_group_classifications_for_treename resolves the relation' do
          relations = { 'group_relation' => { 'tree_label' => 'TreeLabel' } }

          DataCycleCore::Feature::UserGroupClassification.stub(:attribute_relations, relations) do
            hash = { 'v' => 'TreeLabel' }
            Params.transform_with_user_group_classifications_for_treename(hash, nil)

            assert_equal 'classification_alias_ids', hash['t']
            assert_equal 'TreeLabel', hash['n']
          end
        end

        test 'with_user_group_classifications_for_treename raises when the relation is missing' do
          DataCycleCore::Feature::UserGroupClassification.stub(:attribute_relations, {}) do
            assert_raises(StandardError) do
              Params.transform_with_user_group_classifications_for_treename({ 'v' => 'Unknown' }, nil)
            end
          end
        end
      end
    end
  end
end
