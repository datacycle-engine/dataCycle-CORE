# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CollectionHelperTest < ActionView::TestCase
    include DataCycleCore::CollectionHelper
    include DataCycleCore::UiLocaleHelper

    attr_reader :current_user

    def current_ability = DataCycleCore::Ability.new(current_user)

    test 'manual_order_allowed? requires list mode, all languages and no filters' do
      assert manual_order_allowed?('list', 'all', [])
      assert manual_order_allowed?('list', ['all'], nil)
      assert_not manual_order_allowed?('grid', 'all', [])
      assert_not manual_order_allowed?('list', 'de', [])
      assert_not manual_order_allowed?('list', 'all', ['some_filter'])
    end

    test 'selected_collections? is true when a collection contains the content' do
      collection = struct_double(watch_list_data_hashes: [struct_double(thing_id: 'a'), struct_double(thing_id: 'b')])

      assert selected_collections?([collection], 'b')
      assert_not selected_collections?([collection], 'z')
      assert_not selected_collections?([], 'a')
    end

    test 'bulk_update_types only offers override for non-classification properties' do
      check_boxes = bulk_update_types({ 'type' => 'string' })

      assert_equal ['override'], check_boxes.map(&:value)
    end

    test 'bulk_update_types adds add/remove for multiple classifications' do
      prop = { 'type' => 'classification', 'ui' => { 'edit' => { 'options' => { 'multiple' => true } } } }
      check_boxes = bulk_update_types(prop)

      assert_equal ['override', 'add', 'remove'], check_boxes.map(&:value)
    end

    test 'watch_list_list_title renders the name and api/shares markers' do
      plain = watch_list_list_title(struct_double(name: 'Plain', api: false, collection_shares: []))

      assert_includes plain, 'Plain'
      assert_includes plain, 'content-title'
      assert_not_includes plain, 'fa-users'

      shared = watch_list_list_title(struct_double(name: 'Shared', api: true, collection_shares: [Object.new]))

      assert_includes shared, 'fa-users'
      assert_includes shared, 'API'
    end

    test 'get_collection_groups groups a provided collection_group when grouping is enabled' do
      c1 = struct_double(full_path_names: ['Region', 'City'])
      c2 = struct_double(full_path_names: ['Topic'])

      DataCycleCore::Feature::CollectionGroup.stub(:enabled?, true) do
        collections, groups, next_index, nested, title = get_collection_groups({ collection_group: ['My Group', [c1, c2]] })

        assert_equal [c1, c2], collections
        assert_equal ['Region', 'Topic'], groups.keys
        assert_equal 1, next_index
        assert nested
        assert_equal 'My Group', title
      end
    end

    test 'get_collection_groups wraps collections in a single nil group when grouping is disabled' do
      c1 = struct_double(full_path_names: ['Region'])

      DataCycleCore::Feature::CollectionGroup.stub(:enabled?, false) do
        collections, groups = get_collection_groups({ collection_group: ['Group', [c1]] })

        assert_equal({ nil => collections }, groups)
      end
    end

    test 'get_collection_groups loads accessible watch lists when no group is provided' do
      @current_user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')

      DataCycleCore::Feature::CollectionGroup.stub(:enabled?, false) do
        collections, groups, next_index, nested, title = get_collection_groups({ q: 'query' })

        assert_kind_of ActiveRecord::Relation, collections
        assert_equal [nil], groups.keys
        assert_equal 1, next_index
        assert_nil nested
        assert_nil title
      end
    end

    test 'bulk_edit_button_title appends content lock information' do
      lock = struct_double(
        user: struct_double(full_name: 'Jane Doe'),
        locked_for: 5.minutes.ago,
        activitiable: struct_double(first_available_locale: :de, title: 'Locked POI'),
        id: 'lock-1'
      )

      html = bulk_edit_button_title([lock], struct_double(things: []))

      assert_includes html, 'Jane Doe'
      assert_includes html, 'content-lock-lock-1'
    end

    test 'render_my_selection returns nil when the feature is disabled' do
      DataCycleCore::Feature::MySelection.stub(:enabled?, false) do
        assert_nil render_my_selection(type: 'add')
      end
    end

    test 'render_my_selection clears the selection and renders the link when enabled' do
      @current_user = struct_double(my_selection: struct_double(clear_if_not_active: nil))

      DataCycleCore::Feature::MySelection.stub(:enabled?, true) do
        stub(:render, 'RENDERED') do
          assert_equal 'RENDERED', render_my_selection(type: 'add', content: nil)
        end
      end
    end
  end
end
