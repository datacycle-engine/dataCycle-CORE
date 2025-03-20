# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ThingHistoryLinkTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      @thing1 = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'test1' })
      @thing2 = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'test2' })
      @thing3 = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'test3' })
      @thing4 = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: 'test4' })
    end

    test 'thing_history_links - new things have no history' do
      assert_equal 0, @thing1.thing_history_links.size
    end

    test 'thing_history_links - history of merged thing' do
      @thing1.merge_with_duplicate(@thing2)
      assert_equal 1, @thing1.thing_history_links.size
    end

    test 'thing_history_links - history of multiple merged things 1' do
      @thing1.merge_with_duplicate(@thing2)
      @thing1.merge_with_duplicate(@thing3)
      assert_equal 2, @thing1.thing_history_links.size
    end

    test 'thing_history_links - history of multiple merged things 2' do
      @thing1.merge_with_duplicate(@thing2)
      @thing1.merge_with_duplicate(@thing3)
      @thing4.merge_with_duplicate(@thing1)
      assert_equal 3, @thing4.thing_history_links.size
    end
  end
end
