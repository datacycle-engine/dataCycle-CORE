# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CollectionGroupTest < ActiveSupport::TestCase
    setup do
      @collection_path = 'tests / TestWatchList'
      @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: @collection_path)
    end

    test 'collection folders are created correct' do
      @collection_path2 = 'tests  / TestWatchList2'
      @watch_list2 = DataCycleCore::TestPreparations.create_watch_list(name: @collection_path2)
      path_items = @watch_list.full_path.split(DataCycleCore::Feature::CollectionGroup.separator)

      assert_equal @collection_path.squish, @watch_list.full_path
      assert_equal @collection_path2.squish, @watch_list2.full_path
      assert_equal @watch_list.full_path_names, @watch_list2.full_path_names
      assert_equal path_items.last, @watch_list.name
      assert_equal path_items[0...-1], @watch_list.full_path_names
    end

    test 'fulltext_search find correct collection' do
      @watch_list1 = DataCycleCore::TestPreparations.create_watch_list(name: 'tests / Collection1')
      @watch_list2 = DataCycleCore::TestPreparations.create_watch_list(name: 'Collection2')

      assert_equal 1, DataCycleCore::WatchList.fulltext_search('TestWatchList').size
      assert_equal 1, DataCycleCore::WatchList.fulltext_search('Collection1').size
      assert_equal 1, DataCycleCore::WatchList.fulltext_search('Collection2').size
      assert_equal 2, DataCycleCore::WatchList.fulltext_search('Collection').size
      assert_equal 2, DataCycleCore::WatchList.fulltext_search('tests').size
    end
  end
end
