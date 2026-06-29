# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class ObjectTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Object
        end

        test 'tour_start_location builds a place hash from the start point of the line' do
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          line = factory.line_string([factory.point(11.0, 46.0, 100.0), factory.point(11.1, 46.1, 200.0)])
          content = struct_double(line:)

          value = subject.tour_start_location(content:, virtual_definition: { 'type' => 'object' })

          assert_in_delta(46.0, value.latitude)
          assert_in_delta(11.0, value.longitude)
          assert_in_delta(100.0, value.elevation)
          assert_equal('startLocation', value.location_name)
        end

        test 'tour_start_location omits elevation for a zero elevation start point' do
          factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
          line = factory.line_string([factory.point(11.0, 46.0, 0.0), factory.point(11.1, 46.1, 0.0)])
          content = struct_double(line:)

          value = subject.tour_start_location(content:, virtual_definition: { 'type' => 'object' })

          assert_nil(value.elevation)
        end

        test 'tour_start_location returns nil without a line' do
          assert_nil(subject.tour_start_location(content: struct_double(line: nil), virtual_definition: {}))
        end
      end
    end
  end
end
