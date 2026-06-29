# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    # Coverage for Feature::MainFilter - the filter-config assembly used by the
    # content overviews. Most methods transform plain config / selected_filters
    # hashes, so they are driven directly with crafted data; the collaborators on
    # the AdvancedFilter feature are stubbed on the instance.
    class MainFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      end

      def subject
        DataCycleCore::Feature::MainFilter.new
      end

      test 'user_advanced_filters marks selected advanced filters with buttons' do
        config = { filter: [{ type: 'user_advanced' }] }
        selected = [{ 'c' => 'a', 'n' => 'x' }]

        subject.user_advanced_filters(@user, config, selected)
        advanced = config[:filter].first

        assert_equal selected, advanced[:filters]
        assert(advanced[:filters].all? { |f| f['buttons'] == true })
      end

      test 'advanced_forced_user_filters hides forced user filters' do
        config = { hidden_filter: [] }
        selected = [{ 'c' => 'uf' }]

        subject.advanced_forced_user_filters(@user, config, selected)

        assert_equal selected, config[:hidden_filter]
      end

      test 'advanced_user_filters appends user filters with buttons' do
        config = { filter: [{ type: 'advanced', filters: [] }] }
        selected = [{ 'c' => 'u' }]

        subject.advanced_user_filters(@user, config, selected)
        advanced = config[:filter].first

        assert(advanced[:filters].any? { |f| f['c'] == 'u' && f['buttons'] == true })
      end

      test 'classification_tree_filters resolves aliases for a configured tree' do
        mf = subject
        config = { filter: [{ type: 'classification_tree', config: 'Tags' }], excluded_types: [] }
        selected = [{ 'c' => 's', 'n' => 'Tags', 'v' => ['x'], 'identifier' => 'id-1' }]

        mf.stub(:filterable_classification_aliases, { 'Tags' => [] }) do
          mf.classification_tree_filters(@user, config, selected)
        end
        tree_filter = config[:filter].first

        assert tree_filter.key?(:classification_aliases)
        assert_equal ['x'], tree_filter[:value]
        assert_equal 'id-1', tree_filter[:identifier]
      end

      test 'transform_advanced_filter returns nil for blank data' do
        assert_nil subject.send(:transform_advanced_filter, nil)
      end

      test 'transform_advanced_filter builds a filter hash from advanced filter data' do
        result = subject.send(:transform_advanced_filter, { data: { name: 'n', advancedType: 'q' } }, 'a', 't')

        assert_equal 'a', result['c']
        assert_equal 't', result['t']
        assert_equal 'n', result['n']
        assert_equal 'q', result['q']
        assert_predicate result['identifier'], :present?
      end

      test 'configs_equal? compares the presence of comparable keys' do
        mf = subject

        mf.advanced_filter_feature.stub(:all_filters_with_advanced_type, []) do
          mf.advanced_filter_feature.stub(:filter_requires_n_for_comparison?, false) do
            assert mf.send(:configs_equal?, { 'c' => 'a', 't' => 'x' }, { 'c' => 'a', 't' => 'x' })
            assert_not mf.send(:configs_equal?, { 'c' => 'a' }, { 'c' => 'b' })
          end
        end
      end

      test 'advanced_filters merges visible filters and assigns buttons' do
        mf = subject
        data = { data: { name: 'n', advancedType: 'q' } }
        config = { view_type: 'overview', filter: [{ type: 'advanced', config: {} }], hidden_filter: [] }
        selected = [{ 'c' => 'a', 't' => 'q', 'n' => 'n' }]
        feature = mf.advanced_filter_feature

        feature.stub(:all_available_filters, [['k', 'v', data]]) do
          feature.stub(:available_visible_filters, [['k', 'v', data]]) do
            feature.stub(:all_filters_with_advanced_type, []) do
              feature.stub(:filter_requires_n_for_comparison?, false) do
                mf.advanced_filters(@user, config, selected)
              end
            end
          end
        end
        advanced = config[:filter].first

        assert_kind_of Array, advanced[:filters]
        assert_predicate advanced[:filters], :present?
        assert(advanced[:filters].all? { |f| f['buttons'] == true })
      end

      test 'available_user_advanced_filters returns empty when disabled' do
        mf = subject

        mf.stub(:enabled?, false) do
          assert_equal({}, mf.available_user_advanced_filters(@user, 'overview'))
        end
      end

      test 'available_user_advanced_filters groups configured filters by translated group' do
        mf = subject
        config = { config: { 'overview' => { filter: [{ 'user_advanced' => { 'grp' => 'val' } }] } } }
        feature = mf.advanced_filter_feature

        mf.stub(:enabled?, true) do
          mf.stub(:configuration, config) do
            feature.stub(:try, nil) do
              feature.stub(:default, [['name', 'group1']]) do
                result = mf.available_user_advanced_filters(@user, 'overview')

                assert_kind_of Hash, result
                assert_includes result.keys, 'group1'
              end
            end
          end
        end
      end
    end
  end
end
