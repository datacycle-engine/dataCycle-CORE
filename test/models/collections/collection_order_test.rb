# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Collections
    class CollectionOrderTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @collection = DataCycleCore::TestPreparations.create_watch_list(name: 'Inhaltssammlung 1')
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1 in Collection' }, prevent_history: true)
        @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 2 in Collection' }, prevent_history: true)
        @content3 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 3 in Collection' }, prevent_history: true)
        @content4 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 4 in Collection' }, prevent_history: true)
        @content5 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 5 in Collection' }, prevent_history: true)

        @content.watch_lists << @collection
        @content2.watch_lists << @collection
        @content3.watch_lists << @collection
        @content4.watch_lists << @collection
        @content5.watch_lists << @collection
      end

      test 'default order for new elements' do
        assert_equal [@content.id, @content2.id, @content3.id, @content4.id, @content5.id], @collection.watch_list_data_hashes.order(order_a: :asc).pluck(:hashable_id)
        assert_equal [nil, nil, nil, nil, nil], @collection.watch_list_data_hashes.order(order_a: :asc).pluck(:order_a)
      end

      test 'set manual order flag if it is not set' do
        @collection.update_order_by_array([@content3.id, @content5.id, @content.id, @content4.id, @content2.id])

        assert_equal [@content3.id, @content5.id, @content.id, @content4.id, @content2.id], @collection.watch_list_data_hashes.order(order_a: :asc).pluck(:hashable_id)
        assert_equal true, @collection.manual_order
      end

      test 'set manual order for all watch_list items' do
        @collection.update_order_by_array([@content3.id, @content5.id, @content.id, @content4.id, @content2.id])

        assert_equal [@content3.id, @content5.id, @content.id, @content4.id, @content2.id], @collection.watch_list_data_hashes.order(order_a: :asc).pluck(:hashable_id)
      end

      test 'set manual order for some watch_list items' do
        @collection.update_order_by_array([@content3.id, @content2.id, @content.id])

        assert_equal [@content3.id, @content2.id, @content.id, @content4.id, @content5.id], @collection.watch_list_data_hashes.order(order_a: :asc).pluck(:hashable_id)
      end

      test 'manual default order for search' do
        assert_equal(
          [@content.id, @content2.id, @content3.id, @content4.id, @content5.id],
          DataCycleCore::Filter::Search.new.watch_list_id(@collection.id).sort_collection_manual_order('ASC', @collection.id).query.ids
        )
      end

      test 'changed manual default order for search' do
        @collection.update_order_by_array([@content3.id, @content2.id, @content.id])

        assert_equal(
          [@content3.id, @content2.id, @content.id, @content4.id, @content5.id],
          DataCycleCore::Filter::Search.new.watch_list_id(@collection.id).sort_collection_manual_order('ASC', @collection.id).query.ids
        )
      end
    end
  end
end
