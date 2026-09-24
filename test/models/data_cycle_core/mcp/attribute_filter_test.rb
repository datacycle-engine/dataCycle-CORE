# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the translation of MCP attribute conditions into the ApiService filter
    # structure.
    #
    # The core is the case of a "condition that cannot filter": it used to be skipped silently, the
    # call returned the unfiltered total and applied_filters named the attribute all the same -- a
    # response that looks filtered and is read as "that many exist with it".
    class AttributeFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # The query is never reached in these cases: build_filters raises before any filtering. A
      # placeholder instead of a real Filter::Search keeps the test independent of seed data.
      NO_QUERY = nil

      test 'a condition without in/not_in is a request error, not a silent no-op' do
        error = assert_raises(DataCycleCore::Error::Api::BadRequestError) do
          filter.apply(NO_QUERY, [{ attribute: 'bookable' }])
        end

        assert_equal 'attributes[0]', error.data[:parameter_path]
        assert_includes error.data[:detail], 'bookable'
      end

      test 'an empty in object is rejected as well' do
        assert_raises(DataCycleCore::Error::Api::BadRequestError) do
          filter.apply(NO_QUERY, [{ attribute: 'bookable', in: {} }])
        end
      end

      test 'the reported index points at the offending condition' do
        error = assert_raises(DataCycleCore::Error::Api::BadRequestError) do
          filter.apply(NO_QUERY, [{ attribute: 'bookable', in: { bool: true } }, { attribute: 'numberOfRooms' }])
        end

        assert_equal 'attributes[1]', error.data[:parameter_path]
      end

      test 'a blank attribute name is rejected' do
        assert_raises(DataCycleCore::Error::Api::BadRequestError) do
          filter.apply(NO_QUERY, [{ in: { bool: true } }])
        end
      end

      # Without conditions the query stays unchanged -- that is the only permitted no-op.
      test 'no conditions leaves the query untouched' do
        query = Object.new

        assert_same query, filter.apply(query, [])
        assert_same query, filter.apply(query, nil)
      end

      test 'valid conditions map onto the ApiService in/notIn structure' do
        conditions = [
          { attribute: 'numberOfRooms', in: { min: 50 } },
          { attribute: 'bookable', not_in: { bool: true } }
        ]

        filters = filter.send(:build_filters, conditions)

        assert_equal({ numberOfRooms: { in: { min: 50 } }, bookable: { notIn: { bool: true } } }, filters)
      end

      private

      def filter
        DataCycleCore::Mcp::AttributeFilter.new
      end
    end
  end
end
