# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      class LinkedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Compute::Linked
        end

        test 'from_geo_shape resolves linked things intersecting a geometry string' do
          content = struct_double(id: SecureRandom.uuid)

          DataCycleCore::StoredFilter.stub(:from_property_definition, struct_double(things: DataCycleCore::Thing.none)) do
            value = subject.from_geo_shape(
              content:,
              computed_parameters: { 'geo' => 'POINT (14.5 46.5)' },
              computed_definition: { 'compute' => { 'parameters' => ['geo'] } }
            )

            assert_equal([], value)
          end
        end

        test 'from_geo_shape converts a geographic object to a geometry string' do
          point = DataCycleCore::MasterData::DataConverter.string_to_geographic('POINT (14.5 46.5)')

          DataCycleCore::StoredFilter.stub(:from_property_definition, struct_double(things: DataCycleCore::Thing.none)) do
            value = subject.from_geo_shape(
              content: nil,
              computed_parameters: { 'geo' => point },
              computed_definition: { 'compute' => { 'parameters' => ['geo'] } }
            )

            assert_equal([], value)
          end
        end

        test 'from_geo_shape returns nil when no location values are present' do
          value = subject.from_geo_shape(
            content: nil,
            computed_parameters: { 'geo' => nil },
            computed_definition: { 'compute' => { 'parameters' => ['geo'] } }
          )

          assert_nil(value)
        end

        test 'website traverses the linked content hierarchy for parent websites' do
          value = subject.website(computed_parameters: { 'is_linked_to' => [SecureRandom.uuid] })

          assert_equal([], value)
        end
      end
    end
  end
end
