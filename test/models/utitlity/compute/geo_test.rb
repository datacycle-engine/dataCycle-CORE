# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class GeoTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Geo
        end

        test 'coordinates_to_value extracts a single coordinate by key' do
          parameters = { 'location' => 'POINT (14.5 46.5)' }

          lon = subject.coordinates_to_value(computed_parameters: parameters, computed_definition: { 'compute' => { 'key' => 'x' } })
          lat = subject.coordinates_to_value(computed_parameters: parameters, computed_definition: { 'compute' => { 'key' => 'y' } })

          assert_in_delta(14.5, lon)
          assert_in_delta(46.5, lat)
        end

        test 'coordinates_to_value returns nil when neither a key is configured nor the value is blank' do
          value = subject.coordinates_to_value(
            computed_parameters: { 'location' => 'POINT (14.5 46.5)' },
            computed_definition: { 'compute' => {} }
          )

          assert_nil(value)
        end

        test 'geoshape_from_concept returns nil for blank classification ids' do
          assert_nil(subject.geoshape_from_concept(computed_parameters: { 'areas' => [] }))
        end

        test 'geoshape_from_concept queries classification polygons for the given concepts' do
          ids = get_classification_ids('Tags', 'Tag 1')

          # Tags have no polygons, so the union query returns a blank geometry, but the SQL path is exercised.
          assert_nil(subject.geoshape_from_concept(computed_parameters: { 'areas' => ids }))
        end
      end
    end
  end
end
