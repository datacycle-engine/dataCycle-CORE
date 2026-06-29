# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the (legacy) StoredFilterByGlobal ability segment - the StoredFilter
  # subject and the empty conditions hash.
  class StoredFilterByGlobalSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'exposes the StoredFilter subject and empty conditions' do
      seg = DataCycleCore::Abilities::Segments::StoredFilterByGlobal.new

      assert_equal DataCycleCore::StoredFilter, seg.subject
      assert_equal({}, seg.conditions)
    end
  end
end
