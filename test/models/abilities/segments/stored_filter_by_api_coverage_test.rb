# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the StoredFilterByApi ability segment - the StoredFilter subject and the
  # api: true conditions hash.
  class StoredFilterByApiSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'exposes the StoredFilter subject and the api conditions' do
      seg = DataCycleCore::Abilities::Segments::StoredFilterByApi.new

      assert_equal DataCycleCore::StoredFilter, seg.subject
      assert_equal({ api: true }, seg.conditions)
    end
  end
end
