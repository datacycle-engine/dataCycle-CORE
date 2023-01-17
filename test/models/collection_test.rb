# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CollectionTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @collection = DataCycleCore::TestPreparations.create_watch_list(name: 'Inhaltssammlung 1')
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1 in Collection' }, prevent_history: true)
      @content.watch_lists << @collection
    end

    test 'user has my_selection' do
      user = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      assert user.my_selection
    end

    test 'clear_if_not_active does not clear normal collection' do
      @collection.clear_if_not_active

      assert_equal 1, @collection.reload.things.size
    end

    test 'clear_if_not_active does not clear my_selection with active contents' do
      @collection.update_column(:my_selection, true)

      @collection.clear_if_not_active

      assert_equal 1, @collection.reload.things.size
    end

    test 'clear_if_not_active does clear my_selection after 12 hours' do
      @collection.update_column(:my_selection, true)

      @collection.watch_list_data_hashes.first.update_column(:updated_at, 13.hours.ago)

      @collection.clear_if_not_active

      assert_equal 0, @collection.reload.things.size
    end
  end
end
