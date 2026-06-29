# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module Serializer
      # Coverage for the Gpx serializer's #serialize: the author metadata block and
      # the LineString track branch. Driven by a content double with a real RGeo
      # line string; the universal url helper is stubbed so no routing host is needed.
      class GpxCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def factory
          @factory ||= RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
        end

        def line_string
          factory.line_string([factory.point(11.0, 47.0, 600), factory.point(11.5, 47.5, 700)])
        end

        def content_double(geom:)
          user = Object.new
          user.define_singleton_method(:name) { 'Jane Doe' }
          obj = Object.new
          obj.define_singleton_method(:title) { 'My Track' }
          obj.define_singleton_method(:id) { 'gpx-1' }
          obj.define_singleton_method(:updated_at) { Time.zone.at(1_700_000_000) }
          obj.define_singleton_method(:created_by_user) { user }
          obj.define_singleton_method(:geo_properties) { { 'route' => { 'label' => 'Route' } } }
          obj.define_singleton_method(:route) { geom }
          obj
        end

        test 'serialize emits an author block and a track for a line string' do
          result = DataCycleCore::Serialize::Serializer::Gpx.stub(:api_v4_universal_url, 'https://example.com/x') do
            DataCycleCore::Serialize::Serializer::Gpx.send(:serialize, content_double(geom: line_string), 'de')
          end

          assert_kind_of(DataCycleCore::Serialize::SerializedData::Content, result)
          assert_includes(result.data, '<author>')
          assert_includes(result.data, 'Jane Doe')
          assert_includes(result.data, '<trk>')
        end
      end
    end
  end
end
