# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Virtual
      class GeographicTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::Virtual::Geographic
        end

        test 'line_string_union merges the line strings of the linked contents' do
          factory = RGeo::Geographic.spherical_factory(srid: 4326)
          line = factory.line_string([factory.point(11.0, 46.0), factory.point(11.1, 46.1)])
          route = struct_double(track: line)
          content = struct_double(routes: [route])

          value = subject.line_string_union(virtual_parameters: ['routes', 'track'], content:)

          assert_kind_of(RGeo::Feature::MultiLineString, value)
          assert_equal(1, value.num_geometries)
        end

        test 'line_string_union returns nil when there are no line strings' do
          content = struct_double(routes: [])

          assert_nil(subject.line_string_union(virtual_parameters: ['routes', 'track'], content:))
        end
      end
    end
  end
end
