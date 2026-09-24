# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Mcp
    # Unit tests for the resolution of the sort parameter. The core is that an unusable sort key
    # produces an ERROR and does not silently fall back to the editorial default ordering: with a
    # limit in front, the result would look like a ranking but be an arbitrary subset -- i.e. a
    # plausible wrong answer to "the 5 longest tours".
    class SortScopeTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # In these cases validate! raises before the query is touched -- a placeholder keeps the test
      # independent of seed data (as in attribute_filter_test).
      NO_QUERY = nil
      NO_TEMPLATES = [].freeze

      test 'no sort argument means no scope, so the caller keeps sort_default' do
        assert_nil DataCycleCore::Mcp::SortScope.build({}, template_names: NO_TEMPLATES)
        assert_nil DataCycleCore::Mcp::SortScope.build({ sort: nil }, template_names: NO_TEMPLATES)
      end

      test 'an unknown direction is a request error and names the allowed values' do
        error = assert_raises(DataCycleCore::Error::Api::BadRequestError) do
          apply(attribute: 'dct:created', direction: 'sideways')
        end

        assert_equal 'sort.direction', error.data[:parameter_path]
        DataCycleCore::Mcp::SortScope::DIRECTIONS.each { |d| assert_includes error.data[:detail], d }
      end

      test 'a blank attribute is a request error' do
        error = assert_raises(DataCycleCore::Error::Api::BadRequestError) { apply(attribute: '') }

        assert_equal 'sort.attribute', error.data[:parameter_path]
      end

      # The distance sort needs the point it sorts around. Without near, the scope would sort by a
      # reference point that does not exist -- so the error names the missing filter.
      test 'sorting by distance without near is a request error that names near' do
        error = assert_raises(DataCycleCore::Error::Api::BadRequestError) { apply(attribute: 'distance') }

        assert_equal 'sort.attribute', error.data[:parameter_path]
        assert_includes error.data[:detail], 'near'
      end

      # Without the list in the error a client keeps trying variants of the same key or falls back to
      # query -- both lead to an unordered response again.
      test 'a non-sortable attribute is rejected with the list of sortable keys' do
        error = assert_raises(DataCycleCore::Error::Api::BadRequestError) { apply(attribute: 'not_a_sortable_attribute') }

        assert_equal 'sort.attribute', error.data[:parameter_path]
        DataCycleCore::Mcp::SortScope::BUILT_INS.each_key { |key| assert_includes error.data[:detail], key }
      end

      test 'every raised parameter path stays under the sort prefix the client sent' do
        ['', 'not_a_sortable_attribute', 'distance'].each do |attribute|
          error = assert_raises(DataCycleCore::Error::Api::BadRequestError) { apply(attribute:) }

          assert_match(/\Asort\./, error.data[:parameter_path], attribute)
          assert_equal DataCycleCore::Mcp::BadRequest::DEFAULT_TYPE, error.data[:type]
        end
      end

      # The default direction carries the meaning of the question: "the longest" is desc, "the
      # nearest" asc. A uniform default would return half the rankings the wrong way round.
      test 'the default direction follows the attribute, not one global default' do
        assert_equal 'desc', scope(attribute: 'dct:created').to_h[:direction]
        assert_equal 'asc', scope(attribute: 'name').to_h[:direction]
      end

      test 'an explicitly requested direction wins over the default' do
        assert_equal 'asc', scope(attribute: 'dct:created', direction: 'asc').to_h[:direction]
      end

      # The distance sort is the only sort key needing a SECOND parameter (near), and that arrives as
      # a nested JSON object with STRING keys (Tools::Base now normalises at the entrance, measured
      # there). With @near[:lon] on a string-keyed hash, geo_value produced [nil, nil], and
      # Filter::Sortable#sort_proximity_geographic discards invalid coordinates SILENTLY
      # (`return self unless valid_geographic_coordinates?`): the list came back unsorted while
      # applied_filters.sort presented it as a distance ranking. Exactly the silent wrong answer this
      # class is written against -- hence both key forms.
      test 'the distance sort forwards the point no matter how near is keyed' do
        [{ 'lat' => 47.1, 'lon' => 9.8, 'radius_km' => 5 }, { lat: 47.1, lon: 9.8, radius_km: 5 }].each do |near|
          recorder = SortRecorder.new
          DataCycleCore::Mcp::SortScope
            .build({ sort: { attribute: 'distance' }, near: }, template_names: NO_TEMPLATES)
            .apply(recorder)

          assert_equal [:sort_proximity_geographic, 'asc', [9.8, 47.1]], recorder.call,
                       "near mit #{near.keys.first.class}-Schlüsseln muss denselben Punkt weitergeben"
        end
      end

      private

      # Records the scope call instead of building a real Filter::Search: what is checked is WHICH
      # point arrives at the sort scope -- a real query would discard the invalid point silently and
      # the test would have shown precisely nothing.
      class SortRecorder
        attr_reader :call

        def sort_proximity_geographic(direction, value)
          @call = [:sort_proximity_geographic, direction, value]
          self
        end
      end

      def scope(sort)
        DataCycleCore::Mcp::SortScope.build({ sort: }, template_names: NO_TEMPLATES)
      end

      def apply(sort)
        scope(sort).apply(NO_QUERY)
      end
    end
  end
end
