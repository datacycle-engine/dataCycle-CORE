# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for DataCycleCore::WatchList helper methods that are not exercised
  # by the integration suite (driven by an unsaved WatchList).
  class WatchListCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def watch_list
      DataCycleCore::WatchList.new(name: 'Coverage WatchList')
    end

    test 'WatchList.watch_list_data_hashes builds a scoped relation' do
      relation = DataCycleCore::WatchList.where(id: nil).watch_list_data_hashes

      assert_kind_of(ActiveRecord::Relation, relation)
      assert_empty(relation.to_a)
    end

    test 'to_hash excludes the user_id attribute' do
      assert_not_includes(watch_list.to_hash.keys, 'user_id')
    end

    test 'to_select_option builds a select option' do
      assert_kind_of(DataCycleCore::Filter::SelectOption, watch_list.to_select_option)
    end

    test 'to_stored_filter uses the default sort for a non-persisted list' do
      filter = watch_list.to_stored_filter

      assert_kind_of(DataCycleCore::StoredFilter, filter)
      assert_equal([{ 'm' => 'default' }], filter.sort_parameters)
    end
  end
end
