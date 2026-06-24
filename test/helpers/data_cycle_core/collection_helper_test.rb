# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CollectionHelperTest < ActionView::TestCase
    include DataCycleCore::CollectionHelper
    include DataCycleCore::UiLocaleHelper

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
  end
end
